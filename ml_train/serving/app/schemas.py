"""Request/response shapes for the AI service."""
from pydantic import BaseModel, Field


# ─────────── Disease detection ───────────
class DiseasePrediction(BaseModel):
    disease: str | None
    confidence: float
    recommendation: str
    top_k: list[dict] = []          # [{"disease": ..., "confidence": ...}, ...]


# ─────────── Fertilizer recommendation ───────────
class FertilizerFeatures(BaseModel):
    """Matches the columns the XGBoost model was trained on."""
    Soil_Type: str = Field(examples=["Clay"])
    Soil_pH: float = Field(examples=[6.07])
    Soil_Moisture: float = Field(examples=[34.98])
    Organic_Carbon: float = Field(examples=[0.32])
    Electrical_Conductivity: float = Field(examples=[1.87])
    Nitrogen_Level: float = Field(examples=[61])
    Phosphorus_Level: float = Field(examples=[44])
    Potassium_Level: float = Field(examples=[84])
    Temperature: float = Field(examples=[19.84])
    Humidity: float = Field(examples=[83.31])
    Rainfall: float = Field(examples=[1693.22])
    Crop_Type: str = Field(examples=["Cotton"])
    Crop_Growth_Stage: str = Field(examples=["Harvest"])
    Season: str = Field(examples=["Kharif"])
    Irrigation_Type: str = Field(examples=["Canal"])
    Previous_Crop: str = Field(examples=["Wheat"])
    Region: str = Field(examples=["South"])
    Fertilizer_Used_Last_Season: float = Field(examples=[297.15])
    Yield_Last_Season: float = Field(examples=[1.19])


class FertilizerPrediction(BaseModel):
    predicted_fertilizer: str
    confidence: float
    top_k: dict = {}                # {fertilizer: probability, ...}


# ─────────── Chatbot ───────────
class ChatRequest(BaseModel):
    question: str = Field(examples=["why is crop rotation important?"])


class ChatResponse(BaseModel):
    question: str
    answer: str
