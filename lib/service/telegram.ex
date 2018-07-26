defmodule GuitarBot.Service.Telegram do

  alias GuitarBot.Service.User

  def get_update_data(update) do
    case update do
      %{inline_query: inline_query} when not is_nil(inline_query) ->
        {:inline_query, get_inline_query_data(inline_query)}
      %{message: message} when not is_nil(message) ->
        {:message, get_message_data(message)}
      %{callback_query: callback_query} when not is_nil(callback_query) ->
        {:callback_query, get_callback_query_data(callback_query)}
    end
  end

  # Use these to put the data that is useful to you into a map (and discard the rest)
  # Don't mix business logic here
  def get_inline_query_data(%{id: id, offset: offset, query: query}) do
    text = query |> String.replace(~r/^@.*\s/, "") |> String.trim |> String.replace(" ", "+")
    %{text: text, id: id, offset: offset}
  end

  def get_message_data(message = %Nadia.Model.Message{}) do
    %{text: message.text, chat_id: message.chat.id, user: message.from}
  end

  def get_callback_query_data(%{data: data, message: message}) do
    %{text: data, chat_id: message.chat.id, user: message.from}
  end


  def send_pdf(chat_id, data) do
    more_of_button = [%{switch_inline_query_current_chat: "#{data.band}", text: "More of #{data.band}"}]
    another_version_button = [%{callback_data: "#{data.band} #{data.name};#{data.version_number + 1}", text: "Get me another version"}]
    inline_keyboard = %{inline_keyboard: [more_of_button, another_version_button]}
    Nadia.send_document(chat_id, data.pdf_path, reply_markup: inline_keyboard)
  end

  def send_error_message(:http_error, chat_id) do
    Nadia.send_message(chat_id, "Sorry, something happened to the connection. Please try again later.")
  end
  def send_error_message(_, chat_id) do
    Nadia.send_message(chat_id, "Sorry, I couldn't find anything.")
  end

  def send_answer_inline_query(inline_query_id, results, _offset \\ 0) do
    results = Enum.take(results, 50) # Telegram max
    inline_results = for result <- results do
      %Nadia.Model.InlineQueryResult.Article{
         type: "article",
         id: "#{result.band}-#{result.name}",
         title: result.band,
         description: result.name,
         input_message_content: %Nadia.Model.InputMessageContent.Text{message_text: "*#{result.band}* - #{result.name}", parse_mode: "Markdown"}
      }
    end
    Nadia.answer_inline_query(inline_query_id, inline_results)
  end

  def broadcast_message(text, user) do
    if ("#{user.id}" == System.get_env("GUITARBOT_BROADCAST_ALLOWED_CHAT_ID")) do
      User.get_users
      |> Enum.map(fn(user)->
        Nadia.send_message(user.chat_id, text)
      end)
    end
  end
end
