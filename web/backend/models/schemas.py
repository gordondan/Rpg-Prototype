from __future__ import annotations

from pydantic import BaseModel, Field


# --- Creatures ---

class LearnsetEntry(BaseModel):
    level: int
    move_id: str


class Evolution(BaseModel):
    creature_id: str
    level: int
    flavor: str


class Creature(BaseModel):
    name: str
    description: str
    types: list[str]
    base_hp: int
    base_attack: int
    base_defense: int
    base_sp_attack: int
    base_sp_defense: int
    base_speed: int
    base_exp: int
    class_: str = Field(alias="class")
    evolution: Evolution | None = None
    recruit_method: str | None = None
    recruit_chance: float | None = None
    recruit_dialogue: str | None = None
    recruitable: bool | None = None
    learnset: list[LearnsetEntry] = []

    model_config = {"populate_by_name": True}


# --- Moves ---

class MoveEffect(BaseModel):
    stat: str | None = None
    stages: int | None = None
    target: str | None = None
    status: str | None = None


class Move(BaseModel):
    name: str
    type: str
    category: str
    power: int
    accuracy: int
    pp: int
    description: str
    effect: MoveEffect | None = None
    effect_chance: int | None = None
    priority: int | None = None


# --- Items ---

class ItemEffect(BaseModel):
    type: str
    amount: int | None = None


class Item(BaseModel):
    name: str
    description: str
    price: int
    effect: ItemEffect


# --- Maps ---

class Encounter(BaseModel):
    creature_id: str
    level_min: int
    level_max: int
    weight: int


class GameMap(BaseModel):
    name: str
    description: str
    encounters: list[Encounter]


# --- Shops ---

class Shop(BaseModel):
    name: str
    greeting: str
    items: list[str]


# --- Dialogue ---

class DialogueChoice(BaseModel):
    text: str
    id: str
    next: list[DialogueLine] = []


class DialogueLine(BaseModel):
    text: str
    speaker: str
    choices: list[DialogueChoice] | None = None


class NPC(BaseModel):
    name: str
    sprite: str
    lines: list[DialogueLine]


# Rebuild for forward references
DialogueChoice.model_rebuild()


# --- Asset Metadata ---

class AssetMeta(BaseModel):
    status: str = "active"
    notes: str = ""


# --- Quests ---

class QuestReward(BaseModel):
    gold: int = 0
    items: list[str] = []
    exp: int = 0


class QuestStage(BaseModel):
    id: str
    type: str  # talk_to_npc, defeat_creatures, collect_items, reach_location, boss_encounter
    description: str
    npc_id: str | None = None
    dialogue_id: str | None = None
    creature_id: str | None = None
    count: int | None = None
    item_id: str | None = None
    map_id: str | None = None
    level: int | None = None


class Quest(BaseModel):
    name: str
    description: str
    map_id: str
    prerequisite_quest_id: str | None = None
    reward: QuestReward
    stages: list[QuestStage]
