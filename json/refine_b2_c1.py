import json
import os

def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

def translate_question_to_english(question, type):
    # Mapping of common Turkish instructions to English
    mappings = {
        "Cümle kurun": "Form a sentence",
        "Sıralayın": "Put in the correct order",
        "Boşluğu doldurun": "Fill in the blank",
        "Çevirin": "Translate the sentence",
        "Eşleştirin": "Match the pairs",
        "Okuyun": "Read aloud",
        "Düzenleyin": "Arrange the words",
        "Birleştirin": "Combine the sentences",
        "Tamamlayın": "Complete the sentence",
        "Seçin": "Choose the correct option",
        "Cevaplayın": "Answer the question",
        "Anlamlarını eşleştirin": "Match the meanings",
        "Zamanları eşleştirin": "Match the tenses",
        "Kullanımları eşleştirin": "Match the usages",
        "Fiilleri eşleştirin": "Match the verbs",
        "Tahmin Edin": "Make a guess",
        "Aktarın": "Report the speech",
        "Vurgulayın": "Emphasize the part",
        "Resmi yapın": "Make it formal",
        "Kullanın": "Use the idiom",
        "Düşünün": "Think and answer",
        "İkna edin": "Persuade",
        "Sunum": "Presentation practice",
        "Karmaşık yapı": "Complex structure practice",
        "Geçmişi değiştirin": "Change the past structure",
        "Yapıyı oluşturun": "Form the structure",
        "Akademik dil": "Use academic language",
        "Participle Clause": "Use a Participle Clause",
        "Subjunctive yapın": "Make it Subjunctive",
        "Collocation": "Use the collocation",
        "Clause tipleri": "Match the clause types"
    }
    
    # Exact match check
    if question in mappings:
        return mappings[question]
        
    # Partial match for common patterns
    if "eşleştirin" in question.lower():
        return "Match the items"
    if "sıralayın" in question.lower():
        return "Put in the correct order"
    if "çevirin" in question.lower():
        return "Translate"
    if "kurun" in question.lower():
        return "Form a sentence"
    if "doldurun" in question.lower():
        return "Fill in the blank"
    if "seçin" in question.lower():
        return "Choose the correct option"
    
    return question # Return original if no match found (will review manually if needed)

def refine_file(path, level):
    data = load_json(path)
    for lesson in data:
        # Title remains in Turkish for now as per instructions "titlelar türkçe kalabilir"
        for exercise in lesson['exercises']:
            # Translate question to English for B2/C1
            if level in ['B2', 'C1']:
                original_q = exercise['question']
                translated_q = translate_question_to_english(original_q, exercise['type'])
                exercise['question'] = translated_q
                
            # Logic/Clarity Checks (Applied to all, but focus on B2/C1 language shift first)
            # Ensure 'options' exists for quiz/fill_blank
            if exercise['type'] in ['quiz', 'fill_blank'] and 'options' not in exercise:
                print(f"Warning: Missing options in {lesson['title']} - {exercise['question']}")
            
            # Additional cleanup if needed
            
    save_json(path, data)
    print(f"Processed {path}")

# Paths
base_path = "c:/Users/merta/duck/json"
files = {
    "B2": os.path.join(base_path, "B2_exercises.json"),
    "C1": os.path.join(base_path, "C1_exercises.json")
}

for level, path in files.items():
    if os.path.exists(path):
        refine_file(path, level)
    else:
        print(f"File not found: {path}")

