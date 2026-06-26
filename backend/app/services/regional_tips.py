"""
Region-specific farming tips shown on the farmer's analytics dashboard.

Keyed by region name (matching database/seed/data/regions.csv). Each tip is a
short, actionable card: a title + a one-paragraph body. Pure data + a tiny
lookup helper — no DB, no FastAPI.
"""

REGIONAL_TIPS: dict[str, list[dict[str, str]]] = {
    "Dhaka": [
        {
            "title": "Control Brown Planthopper in Rice Fields",
            "body": "Regularly inspect the lower portion of rice plants for brown "
                    "planthopper activity, especially during humid weather. Remove "
                    "heavily affected plants and follow integrated pest management "
                    "practices before infestation spreads across the field.",
        },
        {
            "title": "Follow Balanced Fertilizer Application",
            "body": "Apply nitrogen, phosphorus, and potassium according to soil test "
                    "recommendations. Avoid excessive nitrogen application as it can "
                    "increase pest attacks and reduce crop resilience.",
        },
        {
            "title": "Improve Water Drainage",
            "body": "Clean field canals and drainage pathways before the monsoon "
                    "season. Standing water for long periods can damage crop roots and "
                    "encourage fungal diseases.",
        },
        {
            "title": "Use High-Yield and Disease-Resistant Seeds",
            "body": "Select certified seed varieties recommended by agricultural "
                    "extension offices. Disease-resistant varieties generally provide "
                    "better yield stability and lower production costs.",
        },
    ],
    "Chattogram": [
        {
            "title": "Protect Fields from Waterlogging",
            "body": "Construct drainage channels around crop fields and use raised "
                    "cultivation beds where possible. Excessive rainfall can reduce "
                    "oxygen availability in the root zone and stunt crop growth.",
        },
        {
            "title": "Prevent Fungal Disease Outbreaks",
            "body": "High humidity encourages diseases such as leaf spot and blight. "
                    "Maintain proper spacing between plants to improve airflow and "
                    "reduce moisture accumulation.",
        },
        {
            "title": "Strengthen Soil Fertility",
            "body": "Apply compost and organic matter regularly to improve soil "
                    "structure and nutrient retention, particularly in areas affected "
                    "by heavy rainfall.",
        },
        {
            "title": "Store Harvested Crops Properly",
            "body": "After harvesting, dry crops thoroughly before storage. Use "
                    "ventilated storage facilities to reduce post-harvest losses "
                    "caused by mold and moisture.",
        },
    ],
    "Rajshahi": [
        {
            "title": "Prepare for Dry Conditions",
            "body": "Choose drought-tolerant crop varieties and plan irrigation "
                    "schedules carefully during the dry season to minimize water "
                    "stress.",
        },
        {
            "title": "Increase Soil Moisture Retention",
            "body": "Incorporate compost, crop residues, and organic matter into the "
                    "soil. These materials help retain moisture and improve root "
                    "development.",
        },
        {
            "title": "Monitor Mango Orchards Regularly",
            "body": "Inspect mango trees for fruit flies, powdery mildew, and "
                    "anthracnose. Early detection helps prevent significant yield "
                    "losses.",
        },
        {
            "title": "Use Efficient Irrigation Methods",
            "body": "Avoid flooding fields unnecessarily. Drip or controlled "
                    "irrigation methods can reduce water waste and improve crop "
                    "productivity.",
        },
    ],
    "Khulna": [
        {
            "title": "Manage Soil Salinity",
            "body": "Test soil salinity periodically and use salt-tolerant crop "
                    "varieties where necessary. Excess salt can reduce nutrient uptake "
                    "and lower yields.",
        },
        {
            "title": "Prepare for Cyclones and Storm Surges",
            "body": "Harvest mature crops before severe weather events when possible "
                    "and strengthen field embankments to reduce flood damage.",
        },
        {
            "title": "Improve Soil Health with Organic Matter",
            "body": "Apply compost, manure, and crop residues to improve soil "
                    "structure and reduce the negative effects of salinity.",
        },
        {
            "title": "Maintain Proper Irrigation Practices",
            "body": "Use fresh water sources whenever available and avoid excessive "
                    "irrigation that may increase salt accumulation in agricultural "
                    "land.",
        },
    ],
    "Barishal": [
        {
            "title": "Improve Monsoon Drainage Systems",
            "body": "Clean drainage canals before the rainy season and remove "
                    "blockages that can cause prolonged waterlogging in fields.",
        },
        {
            "title": "Prevent Rice Blast Disease",
            "body": "Use resistant rice varieties and avoid excessive nitrogen "
                    "fertilizer. Monitor fields regularly for early symptoms of "
                    "disease.",
        },
        {
            "title": "Optimize Irrigation Management",
            "body": "Provide water according to crop requirements rather than fixed "
                    "schedules. Over-irrigation can reduce root health and nutrient "
                    "efficiency.",
        },
        {
            "title": "Use Certified Disease-Resistant Seeds",
            "body": "Certified seeds often provide higher germination rates and better "
                    "protection against common regional diseases.",
        },
    ],
    "Sylhet": [
        {
            "title": "Reduce Fungal Disease Risk",
            "body": "Frequent rainfall increases fungal infections. Remove infected "
                    "leaves promptly and maintain adequate plant spacing.",
        },
        {
            "title": "Maintain Effective Drainage",
            "body": "Keep drainage channels clear throughout the growing season to "
                    "prevent standing water around crop roots.",
        },
        {
            "title": "Select Varieties Suitable for High-Rainfall Areas",
            "body": "Choose crop varieties recommended for humid environments to "
                    "improve survival and yield performance.",
        },
        {
            "title": "Monitor Tea and Vegetable Crops Frequently",
            "body": "Regular scouting helps identify pests and diseases before they "
                    "spread and cause major economic losses.",
        },
    ],
    "Rangpur": [
        {
            "title": "Protect Potato Crops from Late Blight",
            "body": "Inspect fields regularly, especially during cool and humid "
                    "weather. Remove infected plants and apply recommended fungicides "
                    "when necessary.",
        },
        {
            "title": "Base Fertilizer Use on Soil Testing",
            "body": "Soil testing helps identify nutrient deficiencies and prevents "
                    "unnecessary fertilizer expenses.",
        },
        {
            "title": "Practice Crop Rotation",
            "body": "Rotate potatoes, rice, and other crops to reduce pest "
                    "populations, disease pressure, and soil nutrient depletion.",
        },
        {
            "title": "Prepare for Winter Frost",
            "body": "Monitor weather forecasts and protect sensitive crops using mulch "
                    "or temporary coverings during cold periods.",
        },
    ],
    "Mymensingh": [
        {
            "title": "Follow Recommended Fertilizer Schedules",
            "body": "Apply fertilizers at the correct growth stages to maximize "
                    "nutrient uptake and crop development.",
        },
        {
            "title": "Implement Integrated Pest Management",
            "body": "Use pest monitoring, biological controls, and selective pesticide "
                    "applications to minimize crop damage.",
        },
        {
            "title": "Maintain Field Hygiene",
            "body": "Remove weeds, crop residues, and diseased plants regularly to "
                    "reduce pest breeding grounds and disease spread.",
        },
        {
            "title": "Monitor Crop Growth and Soil Conditions",
            "body": "Regular field inspections help identify nutrient deficiencies, "
                    "irrigation problems, and disease symptoms before they become "
                    "severe.",
        },
    ],
}

# Shown when the farmer has no region set, or an unrecognised region name.
_GENERIC_TIPS: list[dict[str, str]] = [
    {
        "title": "Test Your Soil Before Each Season",
        "body": "A soil test tells you exactly which nutrients your field needs, so "
                "you can apply the right fertilizer and avoid wasting money on the "
                "wrong inputs.",
    },
    {
        "title": "Scout Your Fields Weekly",
        "body": "Walking your fields regularly helps you catch pests and diseases "
                "early, when they are far cheaper and easier to control.",
    },
    {
        "title": "Use Certified, Disease-Resistant Seeds",
        "body": "Certified seed varieties germinate more reliably and resist common "
                "local diseases, giving you steadier yields season after season.",
    },
]


def tips_for_region(region_name: str | None) -> list[dict[str, str]]:
    """Return the tip cards for a region, falling back to generic tips."""
    if region_name and region_name in REGIONAL_TIPS:
        return REGIONAL_TIPS[region_name]
    return _GENERIC_TIPS
