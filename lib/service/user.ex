defmodule GuitarBot.Service.User do

  alias GuitarBot.{Repo, User}

  def insert_user(user) do
    user = user
    |> Map.from_struct
    |> Map.put(:chat_id, user.id)
    |>(&User.changeset(%User{},&1)).()
    |> Repo.insert
  end

  def get_users() do
    Repo.all(User)
  end
end
