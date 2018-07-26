defmodule GuitarBot.Otp.Worker do
  use GenServer
  require Logger

  alias GuitarBot.Service.{TabScraper, Telegram, User}
  defmodule State do
    defstruct update_id: 0
  end

  ## Client API
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  ## Server Callbacks
  def init(:ok) do
    Process.send_after(self(), :get_updates, 1000)
    {:ok, %State{}}
  end

  def handle_info(:get_updates, state = %State{update_id: update_id}) do
    update_id = case Nadia.get_updates(offset: update_id + 1) do
      {:ok, updates}  ->
        for update <- updates do
          Logger.info("#{inspect update}")
          spawn(fn ->
            update
            |> Telegram.get_update_data
            |> process_update
          end)
        end
        (updates |> List.last || %{}) |> Map.get(:update_id) || update_id
      error ->
        Logger.error("#{inspect error}")
        update_id
    end

    Process.send_after(self(), :get_updates, 500)
    {:noreply, %{state | update_id: update_id}}
  end

  def process_update({:inline_query, data}) do
    case TabScraper.search_text(data.text) do
      {:ok, results} ->
        results = case is_integer(data.offset) do
          true -> Enum.drop(results, data.offset)
          false -> results
        end
        Telegram.send_answer_inline_query(data.id, results, data.offset)
      error -> Logger.warn("#{inspect error}") # Reportarme error a mi
    end
  end
  def process_update({:message, data}) do
    spawn(fn -> User.insert_user(data.user) end)
    case data.text do
      "/broadcast " <> message -> Telegram.broadcast_message(message, data.user)
      _ -> handle_song_request(data.text, 0, data.chat_id)
    end
  end
  def process_update({:callback_query, data}) do
    spawn(fn -> User.insert_user(data.user) end)
    [text, version] = String.split(data.text, ";", parts: 2)
    version = case Integer.parse(version) do
      {number, _} when is_integer(number) -> number
      _ -> 0
    end
    case data.text do
      _ -> handle_song_request(text, version, data.chat_id)
      #TODO: cases para otros botones
    end
  end

  def handle_song_request(text, version, chat_id, retry \\ true) do
    case TabScraper.get_song(text, version) do
      {:ok, data} -> Telegram.send_pdf(chat_id, data)
      {:error, error} when error == :http_error ->
        case retry do
           true -> handle_song_request(text, version, chat_id, false)
           false -> Telegram.send_error_message(error, chat_id)
        end
      {:error, error} -> Telegram.send_error_message(error, chat_id) # TODO Hacer una función genérica que responda mensaje según atom (ej.: :no_versions)
      error -> Logger.warn("#{inspect error}") # Reportarme error a mi
    end
  end

end
