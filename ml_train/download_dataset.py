from datasets import load_dataset

dataset = load_dataset("KisanVaani/agriculture-qa-english-only")

df = dataset["train"].to_pandas()

df.to_csv("agri_chatbot.csv", index=False)

print(df.head())
print("Dataset downloaded successfully!")