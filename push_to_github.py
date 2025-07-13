#!/usr/bin/env python3
"""
GitHub Push Script
Automatically commits and pushes changes to GitHub
"""

import subprocess
import sys
from datetime import datetime

def run_command(command, description=""):
    """Run a shell command and return the result"""
    try:
        print(f"Running: {description or command}")
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Error: {result.stderr}")
            return False, result.stderr
        
        if result.stdout:
            print(result.stdout)
        return True, result.stdout
    except Exception as e:
        print(f"Exception: {e}")
        return False, str(e)

def main():
    # Get commit message from user or use default
    if len(sys.argv) > 1:
        commit_message = " ".join(sys.argv[1:])
    else:
        commit_message = input("Enter commit message (or press Enter for default): ").strip()
        if not commit_message:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
            commit_message = f"Update project files - {timestamp}"
    
    print(f"Commit message: {commit_message}")
    print("-" * 50)
    
    # Check git status
    success, output = run_command("git status --porcelain", "Checking git status")
    if not success:
        print("Failed to check git status")
        return
    
    if not output.strip():
        print("No changes to commit!")
        return
    
    # Show what will be committed
    print("Files to be committed:")
    run_command("git status --short", "Showing file status")
    
    # Add all changes
    success, _ = run_command("git add .", "Adding all changes")
    if not success:
        print("Failed to add files")
        return
    
    # Create commit with timestamp
    full_commit_message = f"{commit_message}\n\n🤖 Generated with push script\nTimestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    
    success, _ = run_command(f'git commit -m "{full_commit_message}"', "Creating commit")
    if not success:
        print("Failed to create commit")
        return
    
    # Push to GitHub
    success, _ = run_command("git push origin main", "Pushing to GitHub")
    if not success:
        print("Failed to push to GitHub")
        return
    
    print("\n✅ Successfully pushed to GitHub!")
    print(f"Commit message: {commit_message}")

if __name__ == "__main__":
    main()