from __future__ import annotations

import json
import base64
from dataclasses import dataclass

from backend.config import settings


@dataclass
class GridDetection:
    frame_width: int
    frame_height: int
    columns: int
    rows: int
    frame_count: int
    confidence: float  # 0-1


class GeminiService:
    def __init__(self):
        self.api_key = settings.gemini_api_key

    @property
    def available(self) -> bool:
        return bool(self.api_key)

    def detect_sprite_grid(self, image_bytes: bytes, image_width: int, image_height: int) -> GridDetection | None:
        """Use Gemini vision to detect the sprite grid layout in a sprite sheet.

        Returns None if the API key is not configured or if detection fails.
        """
        if not self.available:
            return None

        try:
            from google import genai

            client = genai.Client(api_key=self.api_key)

            b64_image = base64.b64encode(image_bytes).decode("utf-8")

            prompt = f"""Analyze this sprite sheet image ({image_width}x{image_height} pixels).

This is a game sprite sheet containing animation frames arranged in a grid.

Determine:
1. The width and height of each individual frame in pixels
2. The number of columns and rows in the grid
3. The total number of frames (some grid cells at the end may be empty)

Respond with ONLY a JSON object, no other text:
{{"frame_width": <int>, "frame_height": <int>, "columns": <int>, "rows": <int>, "frame_count": <int>, "confidence": <float 0-1>}}"""

            response = client.models.generate_content(
                model="gemini-2.0-flash",
                contents=[
                    {
                        "parts": [
                            {"text": prompt},
                            {
                                "inline_data": {
                                    "mime_type": "image/png",
                                    "data": b64_image,
                                }
                            },
                        ]
                    }
                ],
            )

            text = response.text.strip()
            # Strip markdown code fences if present
            if text.startswith("```"):
                text = text.split("\n", 1)[1]
                text = text.rsplit("```", 1)[0].strip()

            data = json.loads(text)
            return GridDetection(
                frame_width=int(data["frame_width"]),
                frame_height=int(data["frame_height"]),
                columns=int(data["columns"]),
                rows=int(data["rows"]),
                frame_count=int(data["frame_count"]),
                confidence=float(data.get("confidence", 0.5)),
            )
        except Exception as e:
            print(f"[gemini] sprite grid detection failed: {e}")
            return None
