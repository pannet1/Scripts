# Function to recursively delete __pycache__ folders
def delete_pycache(folder):
    for root, dirs, files in os.walk(folder):
        if '__pycache__' in dirs:
            pycache_dir = os.path.join(root, '__pycache__')
            shutil.rmtree(pycache_dir)
            print(f"Deleted {pycache_dir}")

# Call the function with the root directory
delete_pycache('.')
