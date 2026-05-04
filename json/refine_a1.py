import json

def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=4, ensure_ascii=False)

def refine_a1(path):
    data = load_json(path)
    
    # Lesson 0: Alphabet
    lesson_0 = next((l for l in data if l.get('id') == 0 or l.get('lessonId') == 0), None)
    if lesson_0:
        exercises = lesson_0['exercises']
        
        # Fix 1: "Bu kelimeyi hecelere ayırın" -> "Bu kelimeyi harflerine ayırın"
        for ex in exercises:
            if "hecelere ayırın" in ex['question']:
                ex['question'] = "Bu kelimeyi harflerine ayırın (Kodlayın)"
        
        # Fix 2: Remove redundant "A, B, C, D, E" translation exercise or fix it.
        # It's usually better to have a clear task.
        # "Bu harfleri İngilizce yazın" with sentence "A, B, C..." is confusing.
        # We'll remove it.
        exercises[:] = [ex for ex in exercises if not (ex['type'] == 'translation' and ex['sentence'] == "A, B, C, D, E")]
        
        lesson_0['exercises'] = exercises

    # General Scan for A1
    for lesson in data:
        for ex in lesson['exercises']:
            # Consistency check: Ensure all 'speaking' exercises have a 'word' field that acts as the prompt
            if ex['type'] == 'speaking' and 'word' not in ex:
                if 'sentence' in ex:
                    ex['word'] = ex['sentence'] # fallback
            
            # Refine 'word_order' instructions
            if ex['type'] == 'word_order':
                if ex['question'] == "Harfleri doğru sıraya koy: A, B, C, ...":
                     pass # This is fine
                elif "sıraya koy" not in ex['question'] and "düzenleyin" not in ex['question'].lower():
                    ex['question'] = "Kelimeleri doğru sıraya koyun"

    save_json(path, data)
    print(f"Refined {path}")

refine_a1("c:/Users/merta/duck/json/A1_exercises.json")
