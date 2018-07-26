defmodule GuitarBot.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :chat_id, :bigint
      add :first_name, :string
      add :last_name, :string
      add :username, :string
      add :language_code, :string
      add :is_bot, :boolean

      timestamps
    end

    create unique_index(:users, :chat_id, name: :unique_users_chat_id)
  end
end
