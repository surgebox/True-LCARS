This will serve as a living and plyable document that will layout a path. Nothing shall be taken as set in stone, and suggestions and thoughts are more than welcomed. 

## Proposal overview:
> This describes a Linux desktop environment implemented using Quickshell and Hyprland, supported by a modular Python backend. The architecture separates the graphical presentation layer from the system functionality. Allowing the team to independently develop and test core functionalities while using Quick Shell as the final end-user interface.
> A web client is proposed as a secondary development and diagnostic interface. This tool would provide an accessible way to exercise and validate backend functionality without requiring the Quickshell environment, reducing development risk and allow for greater functionality and portfolio value that demonstrates testability, modularity, and group collaboration.

After personally weighing the paths of web vs shell paths, I believe a combination of both is worth the trade-off. We keep the development, testability, and perhaps more familiarity of the technology advantages of the web approach while supplementing it as a tool that can help greatly in the development of the quickshell aspect.
---
# 1.Project Overview
What are we building?
> True-LCARS, inspired by the LCARS computer interface from Star Trek. This will be a Linux desktop environment that will provide a graphical desktop shell, system monitoring, application and file control. We are aiming to sell the idea that we captured a real fully functional operating system as if salvaged from a different world.

**Primary Goals**
- Create a functional LCARS-inspired Linux desktop
- Integrate with Linux Fedora
- Provide real-time system information
- Provide application and desktop controls
- Media controls
- Make core functionality independently testable
- Provide a polished graphical experience
  - From bios/boot screen being Star-trek inspired
  - To login Screen being custom
  - To custom animation once login details entered.
  - To custom shutdown animation
 
**Reaching for the Stars Goals (optional)
- Voice commands
- AI assistance
- Natural-language system commands
- Subtle, immersive, yet non-distracting thematic sounds
- Sky's the limit!

# 2.Architecture

                         LCARS SYSTEM
                              │
                    ┌───-Presentation-──┐
                    │                   │
              QUICKSHELL             WEB UI
              End User              Developers
                    │                   │
                    └─────────┬─────────┘
                              │
                         API / IPC
                              │
                       ┌───────▼──────────┐
                       │  LCARS CORE      │
                       │                  │
                       │  System          │
                       │  Commands        │
                       │  Linux           │
                       │  AI(Star Goal)   │
                       │  Voice(Star Goal)│
                       └───────┬──────────┘
                               │
                           Fedora OS


### Presentation:
Broken down into two for seperation of concerns and testability without requiring the graphical desktop interface.
- QuickShell:
  > QuickShell/Hyprland is the primary end-user interface. This will be the 'window' or experience to the LCARS system. The end-user will only engage with this.
  
- Web UI:
  > The web ui will be secondary and serve development and as a diagnostic tool. The developers should be the only ones making use of this.
  
  The arrival of this decision was to have a way to easily write tests when it comes to expected system stats, keeping it separate so that if the graphical shell does not display expected, we know whether the problem lives in Quickshell or otherwise.

### LCARS CORE
More details in Module Definitions to follow. 
> LCARS CORE encapsulates the functionality of the system. If the Presentation is the marketfront, the core is the meat and veggies.

### Presentation Cherry(expanded)
                  POWER ON
                     │
                     ▼
              ┌──────────────┐
              │    GRUB      │
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │   Plymouth   │
              │              │
              │   Animation  │
              └──────┬───────┘
                     │
                     ▼
       ┌──────────────────────────────┐
       │                              │
       │       CUSTOM GREETER         │
       │                              │
       │    [animated background]     │
       │                              │
       │                              │
       │       ┌──────────────┐       │
       │       │  USER LOGIN  │       │
       │       └──────────────┘       │
       │                              │
       │       [ AUTHENTICATE ]       │
       │                              │
       └──────────────┬───────────────┘
                      │
                      ▼
                 HYPRLAND
                      │
                      ▼
                QUICKSHELL
                      │
                      ▼
              YOUR DESKTOP

>This basically visualized the idea that when booting up the machine, virtual or otherwise, even your bios or screen pre-login will be custom and LCARS themed. Will require some research, but minimal effort anticipated.

### Deliverable
**What are we handing in?**
> While this could easily be just one method, doing multiple 'layers' would presumable be minimal effort. Considering the unpredictable nature of how presentation day will be actually executed. We may as well have every case covered and be prepared to handle all case and choose the quickest, most convenient method that requires minimal user setup.

#### Demo Day's User Experience:
┌───────────────────────────────┐
│       PROJECT ENVIRONMENT     │
│                               │
│  Boot                         │
│    ↓                          │
│  Login                        │
│    ↓                          │
│  Desktop                      │
│    ↓                          │
│  Applications                 │
│    ↓                          │
│  System interaction            │
└───────────────────────────────┘
#### What we deliver
              PROJECT SOURCE
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
    Installer  ISO/Bootable  VM Image
          │         │         │
          └─────────┼─────────┘
                    ▼
             Reproducible
              Environment
**All of the below should be very quick work once we are happy with our build, should probably be tested mid development so no surprises*
### Installer:
Best suited if a user wants to install on an *existing* fedora system. Also allows for any person who is interested to use our repo to install it on their own machine.

Our repo will have an install.sh script that will handle anything necessary to be downloaded and install with one command. Leaving only a reboot to apply the changes.

Existing Fedora machine
        │
        ▼
   Pull from repo
        │
        ▼
   run install.sh in terminal
        │(Contains:)
        ├── dependencies
        ├── Hyprland
        ├── Quickshell
        ├── configuration
        ├── themes/assets
        ├── services
        ├── login/greeter
        └── application integration
        │
        ▼
      Reboot
        │
        ▼
   OUR ENVIRONMENT


### VM Image:
A virtual machine image. Can store on a thumb drive or be downloadable, once the host machine has it, it can be ran via VirtualBox, and everything will be contained and be ready to start up.
**Most likely option given the knowledge of past classes, and the safety to isolate our project in a sandbox**

### Bootable/ISO:
This option is probably the biggest 'wow' factor. On a thumbdrive, we will have everything needed so that a real machine can immediately boot into our system. 
No installation.
No modification to their personal computer or files.
No setup or config.
Insert USB
 │
 ▼
Insert BIOS and boot from Fedora-based project image
 │
 ▼
Boot animation
 │
 ▼
Custom login
 │
 ▼
Hyprland + Quickshell
 │
 ▼
**Complete experience**





