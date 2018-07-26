defmodule GuitarBot.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :chat_id, :integer
    field :first_name, :string
    field :last_name, :string
    field :username, :string
    field :language_code, :string
    field :is_bot, :boolean

    timestamps()
  end

  def changeset(user, params) do
    user
    |> cast(params, [:chat_id, :first_name, :last_name, :username,:language_code, :is_bot])
    |> validate_required([:chat_id])
    |> unique_constraint(:chat_id, name: :unique_users_chat_id)
  end
end