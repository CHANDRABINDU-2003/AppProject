"""
Central configuration. Reads from environment / .env file (see .env.example).
Import `settings` anywhere you need a config value.
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database
    DATABASE_URL: str = "postgresql://agripulse:agripulse@localhost:5432/agripulse"

    # JWT auth
    SECRET_KEY: str = "dev_secret_change_me"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    # External services
    AI_SERVICE_URL: str = "http://localhost:8001"
    WEATHER_API_KEY: str = ""

    # OpenAI (GPT) — when OPENAI_API_KEY is set, the assistant answers come
    # straight from GPT instead of the local FLAN-T5 model.
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"
    OPENAI_BASE_URL: str = "https://api.openai.com/v1"


settings = Settings()
