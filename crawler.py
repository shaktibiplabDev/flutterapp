import os

# Only include Dart files (you can expand if needed)
INCLUDE_EXTENSIONS = {".dart"}

OUTPUT_FILE = "lib_dump.txt"


def crawl_lib_folder(root_dir):
    lib_path = os.path.join(root_dir, "lib")

    if not os.path.exists(lib_path):
        print("❌ 'lib' folder not found!")
        return

    with open(OUTPUT_FILE, "w", encoding="utf-8") as outfile:
        for dirpath, dirnames, filenames in os.walk(lib_path):

            for file in sorted(filenames):
                file_ext = os.path.splitext(file)[1]

                if file_ext not in INCLUDE_EXTENSIONS:
                    continue

                full_path = os.path.join(dirpath, file)
                relative_path = os.path.relpath(full_path, root_dir)

                try:
                    with open(full_path, "r", encoding="utf-8") as f:
                        content = f.read()
                except Exception as e:
                    content = f"[ERROR READING FILE: {e}]"

                # Write formatted output
                outfile.write("\n--------------\n")
                outfile.write(f"{relative_path}\n")
                outfile.write("--------------\n\n")
                outfile.write(content)
                outfile.write("\n\n")

    print(f"✅ Done! Output saved to {OUTPUT_FILE}")


if __name__ == "__main__":
    project_root = os.getcwd()
    crawl_lib_folder(project_root)