"""
Maps a predicted disease class -> short, actionable advice for the farmer.
Keys match ML/plant_disease/data/processed/class_names.json exactly.
"""
DISEASE_ADVICE: dict[str, str] = {
    "Pepper__bell___Bacterial_spot":
        "Remove infected leaves. Apply copper-based bactericide. Avoid overhead irrigation.",
    "Pepper__bell___healthy":
        "Plant looks healthy. Keep monitoring and maintain balanced fertilisation.",
    "Potato___Early_blight":
        "Apply chlorothalonil/mancozeb fungicide. Remove lower infected leaves; rotate crops.",
    "Potato___Late_blight":
        "Act fast — highly destructive. Apply systemic fungicide and destroy infected plants.",
    "Potato___healthy":
        "Plant looks healthy. Maintain good drainage and regular scouting.",
    "Tomato_Bacterial_spot":
        "Use copper sprays. Remove affected foliage. Use disease-free certified seed.",
    "Tomato_Early_blight":
        "Apply mancozeb/chlorothalonil. Mulch soil and prune lower leaves for airflow.",
    "Tomato_Late_blight":
        "Apply protectant fungicide immediately. Remove and destroy infected plants.",
    "Tomato_Leaf_Mold":
        "Improve ventilation/lower humidity. Apply fungicide; avoid leaf wetness.",
    "Tomato_Septoria_leaf_spot":
        "Remove infected leaves. Apply fungicide. Avoid overhead watering; rotate crops.",
    "Tomato_Spider_mites_Two_spotted_spider_mite":
        "Spray miticide or insecticidal soap. Increase humidity; remove heavily infested leaves.",
    "Tomato__Target_Spot":
        "Apply fungicide. Improve airflow and remove plant debris after harvest.",
    "Tomato__Tomato_YellowLeaf__Curl_Virus":
        "Control whitefly vectors. Remove infected plants; use resistant varieties.",
    "Tomato__Tomato_mosaic_virus":
        "No cure — remove infected plants. Disinfect tools and hands; use resistant seed.",
    "Tomato_healthy":
        "Plant looks healthy. Keep monitoring for early signs of disease.",
}


def advice_for(disease: str | None) -> str:
    if not disease:
        return "Could not identify the disease confidently. Please retake a clear photo."
    return DISEASE_ADVICE.get(
        disease, "Consult a local agronomist for a confirmed diagnosis and treatment."
    )
