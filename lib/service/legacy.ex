defmodule GuitarBot.Service.Legacy do
  alias GuitarBot.{Repo, User}
  require Logger

  def import_users(path) do
    File.ls!("#{path}") 
    |> Enum.map(fn(filename) -> File.read!("#{path}/#{filename}") 
      |> String.replace_trailing("\n", "") 
      |> Poison.decode
      |> case do
          {:ok, user} -> 
            User.changeset(%User{},%{
              chat_id: user["id"], 
              username: user["username"] || user["title"],
              first_name: user["first_name"],
              last_name: user["last_name"]
            })
            |> Repo.insert
          error -> Logger.warn("#{inspect error}")  
        end
    end)
    
  end
end

