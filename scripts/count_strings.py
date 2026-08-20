import os
import re
import json

def to_camel_case(s):
    s = re.sub(r'[^a-zA-Z0-9 ]', '', s)
    words = s.split()
    if not words:
        return 'unknown'
    return words[0].lower() + ''.join(w.capitalize() for w in words[1:])

count = 0
files_count = 0
extracted = {}

for root, _, filenames in os.walk('frontend/khair_app/lib'):
    for filename in filenames:
        if filename.endswith('.dart'):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
                
            matches = re.findall(r"(Text|label|hintText|tooltip)\s*[:(]\s*['\"]([^'\"]+)['\"]", content)
            
            if matches:
                files_count += 1
                for match in matches:
                    text_val = match[1]
                    # Skip emojis or extremely short non-alphabetical strings
                    if not re.search(r'[a-zA-Z]', text_val):
                        continue
                    key = to_camel_case(text_val)
                    if len(key) > 30:
                        key = key[:30]
                    # Make key unique if duplicate
                    base_key = key
                    idx = 1
                    while key in extracted and extracted[key] != text_val:
                        key = f"{base_key}{idx}"
                        idx += 1
                    extracted[key] = text_val
                    count += 1

print(f'Found {count} strings in {files_count} files.')
with open('extracted_strings.json', 'w', encoding='utf-8') as f:
    json.dump(extracted, f, indent=2, ensure_ascii=False)
