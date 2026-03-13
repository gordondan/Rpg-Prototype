from pathlib import Path
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    repo_path: Path = Path("/repo")
    data_dir: str = "data"
    assets_dir: str = "assets"
    metadata_file: str = "web/asset_metadata.json"
    git_author_name: str = "RPG Asset Browser"
    git_author_email: str = "rpg-browser@dagordons.com"
    gemini_api_key: str = ""

    @property
    def data_path(self) -> Path:
        return self.repo_path / self.data_dir

    @property
    def assets_path(self) -> Path:
        return self.repo_path / self.assets_dir

    @property
    def metadata_path(self) -> Path:
        return self.repo_path / self.metadata_file


settings = Settings()
