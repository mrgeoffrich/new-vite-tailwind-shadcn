# Project Scaffolding Prompts with Claude

This project is designed to get people up and running with a decent project structure to write web apps using nodejs and Typescript and React for the front end.

# Pre-requisites

* The gh cli.
* Docker (either docker for windows or mac or docker on linux).

# How to use this

## Step 1 - Scaffold up new project (10-12 minutes runtime)

Linux:
```bash
git clone https://github.com/mrgeoffrich/new-vite-tailwind-shadcn
cd new-vite-tailwind-shadcn
./setup.sh "~/repos/new-application"
```

Windows:
```powershell
git clone https://github.com/mrgeoffrich/new-vite-tailwind-shadcn
cd new-vite-tailwind-shadcn
.\run-setup.ps1 C:\my-new-repo"
```

## Step 2 - Implement patterns in new project

Linux:
```bash
cd ~/repos/new-application
claude -p "We have just created this project and are looking to set up and implement some good patterns for organising the code base. Please use @patterns/INSTALL_PATTERNS.md for guidance on how to implement these patterns."
```

Windows:
```powershell
cd C:\my-new-repo
claude -p "We have just created this project and are looking to set up and implement some good patterns for organising the code base. Please use @patterns/INSTALL_PATTERNS.md for guidance on how to implement these patterns."
```
