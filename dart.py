import os

# Define the project path
project_dir = r"C:\Users\ivanm\fleet_control"
output_file = "todos_los_archivos_dart.txt"

# Open the output file in write mode
with open(output_file, 'w', encoding='utf-8') as outfile:
    # Walk through the directory
    for root, dirs, files in os.walk(project_dir):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                
                # Write file header
                outfile.write(f"\n{'='*20}\n")
                outfile.write(f"ARCHIVO: {file_path}\n")
                outfile.write(f"{'='*20}\n\n")
                
                # Write file content
                try:
                    with open(file_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())
                    outfile.write("\n")
                except Exception as e:
                    outfile.write(f"Error leyendo el archivo: {e}\n")

print(f"Archivo generado: {output_file}")
