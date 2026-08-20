import os
import re
import json

def to_camel_case(s):
    s = re.sub(r'[^a-zA-Z0-9 ]', '', s)
    words = s.split()
    if not words:
        return 'unknown'
    return words[0].lower() + ''.join(w.capitalize() for w in words[1:])

def read_json(path):
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def write_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def main():
    en_path = 'frontend/khair_app/lib/l10n/app_en.arb'
    ar_path = 'frontend/khair_app/lib/l10n/app_ar.arb'
    tr_path = 'frontend/khair_app/lib/l10n/app_tr.arb'
    
    en_arb = read_json(en_path)
    ar_arb = read_json(ar_path)
    tr_arb = read_json(tr_path)
    
    existing_en_values = {v: k for k, v in en_arb.items() if not k.startswith('@')}
    
    files_count = 0
    
    for root, _, filenames in os.walk('frontend/khair_app/lib'):
        for filename in filenames:
            if filename.endswith('.dart'):
                filepath = os.path.join(root, filename)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Exclude generated code or l10n files itself
                if 'generated' in filepath or 'l10n' in filepath:
                    continue
                
                matches = re.findall(r"(Text|label|hintText|tooltip|title)\s*[:(]\s*(const\s*)?['\"]([^'\"]+)['\"]", content)
                if not matches:
                    continue
                    
                has_changes = False
                for match in matches:
                    prefix = match[0]
                    is_const = match[1]
                    text_val = match[2]
                    
                    if not re.search(r'[a-zA-Z]', text_val):
                        continue
                        
                    # Fix keys logic
                    key = existing_en_values.get(text_val)
                    if not key:
                        key = to_camel_case(text_val)[:30]
                        if not key or key == 'unknown':
                            continue
                            
                        base_key = key
                        idx = 1
                        while key in en_arb and en_arb[key] != text_val:
                            key = f"{base_key}{idx}"
                            idx += 1
                        
                        en_arb[key] = text_val
                        existing_en_values[text_val] = key
                        ar_arb[key] = text_val
                        tr_arb[key] = text_val
                    
                    old_str = f"{prefix}({is_const}'{text_val}'" if prefix == 'Text' else f"{prefix}: {is_const}'{text_val}'"
                    old_str_dq = f"{prefix}({is_const}\"{text_val}\"" if prefix == 'Text' else f"{prefix}: {is_const}\"{text_val}\""
                    
                    new_str = f"{prefix}(context.l10n.{key}" if prefix == 'Text' else f"{prefix}: context.l10n.{key}"
                    
                    if old_str in content:
                        content = content.replace(old_str, new_str)
                        has_changes = True
                    if old_str_dq in content:
                        content = content.replace(old_str_dq, new_str)
                        has_changes = True

                if has_changes:
                    if "import 'package:khair_app/core/locale/l10n_extension.dart';" not in content and "l10n_extension.dart" not in content:
                        # try to find a good place to insert import, typically after other imports
                        import_stmt = "import 'package:khair_app/core/locale/l10n_extension.dart';\n"
                        # just put it near the top
                        content = import_stmt + content
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    files_count += 1

    write_json(en_path, en_arb)
    write_json(ar_path, ar_arb)
    write_json(tr_path, tr_arb)
    print(f"Modified {files_count} files.")

if __name__ == '__main__':
    main()
