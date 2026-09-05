This will serve as a living and plyable document that will layout a path. Nothing shall be taken as set in stone, and suggestions and thoughts are more than welcomed 

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

### Note on AI and Voice (Overkill AF)
Might be overkill, but I think plausible and might be worthy of learning how to integrate. Atleast to the point of simple voice commands. This can be a WHOLE page's worth of breakdown, and probably will be. To keep it short:
- **NOT** trying to have Siri, gemini, or some other phone ai assistant.
-  Experiment with local ai, or atleast low(free) token usage ai
-  As close to zero user setup needed, if we can have it functional the moment user logs in - amazing.
-  Start with focusing on pre-planned voice commands
-  If we can turn it into intelligently converting natural speech, even better! Instead of "Computer, show me system stats" if we can accept "Computer, How much storage do I have left?" to execute the same output, awesome.
-  If we want to go one step further, if the user says "Computer, I want to watch my Attack on Titan video" and in AI fashion can find a relevant mp4 file sitting within the user's file and start playing it - we'd be cracked.

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

> This basically visualized the idea that when booting up the machine, virtual or otherwise, even your bios or screen pre-login will be custom and LCARS themed. Will require some research, but minimal effort anticipated.

---

### Deliverable
**What are we handing in?**
> While this could easily be just one method, doing multiple 'layers' would presumable be minimal effort. Considering the unpredictable nature of how presentation day will be actually executed. We may as well have every case covered and be prepared to handle all case and choose the quickest, most convenient method that requires minimal user setup.

#### Demo Day's User Experience:
 Boot -> Login -> LCARS System - no setup, no downloading or installing.

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

---
              
**All of the below should be very quick work once we are happy with our build, should probably be tested mid development so no surprises*
### Installer:
Best suited if a user wants to install on an *existing* fedora system. Also allows for any person who is interested to use our repo to install it on their own machine.

Our repo will have an install.sh script that will handle anything necessary to be downloaded and install with one command. Leaving only a reboot to apply the changes.

    Existing Fedora Machine
        │
        ▼
    install.sh
        │
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
    Enter BIOS and boot from Fedora-based img
        │
        ▼
     Boot Animation
        │
        ▼
    Custom login
        │
        ▼
    Hyperland + Quickshell
        │
        ▼
     LCARS EXPERIENCE
---

# Module Breakdown

**This needs more fleshing out, I want to be able to go into more details about how these can be worked on separated, yet hooked up to each other and integrated. To a point where each person can get started with confidence** 9/14 
| Module         | Purpose                                 | Primary Technology   |
| -------------- | --------------------------------------- | -------------------- |
| **LCARS Core** | System logic and Linux integration      | Python               |
| **Quickshell** | Final desktop environment               | QML / Quickshell     |
| **Web Client** | Development/diagnostic interface        | HTML/CSS/JS          |
| **AI**         | Natural-language command interpretation | Python + AI provider |
| **Voice**      | Speech input/output                     | STT/TTS              |
| **Testing**    | Automated/integration testing           | pytest/etc.          |

The more detailed version will probably live in a separate MD file. This currently only represents my vague understanding of all the pieces.


---

# Vague Schedule / Module Breakdown Part 2 
## Foundation
- Repository
  - **I think it'd be beneficial to iron out a document to layout a workflow every one of us can refer to to minimize confusion and understand not only the structure, but workflow to go about doing work and ultimately merging. A git/github 101 page.**  
- Project Structure
- Research APIs that may be needed for different system stats or other functionality.
- Research AI / voice related APIs should AI/voice *if* decided to be integrated.
- Gather up useful resources on visual components, different languages, related projects to learn from, etc
- Rough visual sketches or thought out functional flows on buttons and views. Kinda like planning a website

## - Quickshell Basics
- Basic shell
- LCARS visual components
  -Establish:
    -Shapes
    -Color Palettes
    -Buttons
    -Any visual puzzle pieces to tie in the whole visual look
-Launcher (optional: Incase keyboard-driven is something we wish to support, otherwise, falls under other generic categories)
-Test different resolutions, touch screen friendliness, any visual breaks, ensure expected component behaviors.

## System Integration (Web UI + Quickshell concurrently) 
> Can start developing on web ui side before QuickShell basics. The idea is to be able to cross reference between looking at shell output and web ui, to make sure both are displaying the same thing. And to use it as reference for how one works to make progress on the other.
- System Stats - CPU, RAM, Network, and more
- File viewer and control
- Media control (volume, next, previous, pause)
- Notifications (This is a whole spectrum in itself. Can be none, can be custom. Could be considered in **Polish** section.)

## AI / Voice (Boundary pushing/optional again)
- Command Parser
- AI integration
- Speech-to-text
- Text-to-speech

## Polish
- Pre-login visuals (boot screen, login screen, animation when logging in)
- Animation (optional animations when switching between different panels/views)
- Extensive test usage to tackle logical or graphical bugs
- Performance (should be silk smooth as possible)
- Documentation
- Sounds

>This is just my first rough draft idea of how it can be potentially broken up, just from my current personal understanding. I had a hard time trying to find a way where it can fit into neater buckets that correspond to our in-class roles. That'll be for each person to decide and work out if they'd want to stick so. Even as the 'test engineer' of the group, I think atleast initially, if we go this route, I'd best be fitted tackling the quickshell basics. Although, things such as collecting examples of color values of LCARS' color palette, and shapes, etc, any one can contribute towards. I could also go even deeper in docs on the repo more right before we start working if people find this readable and useful. 
---

### Final notes:
I write all this in the pursue of shifting mindset from saying "This is a project where we made a star trek gui with Python, x , and y" to -> Something closer to : This group school project was used to excersise thinking of systems/ system design :
** Requirements → Architecture → Interfaces → Modules → Ownership → Git workflow → Testing → Integration → Delivery ** 
and being able to talk about it potentially when job hunting.

I consider all of this as a proposal and offering of insight for a rough path I've worked out in my head. While not everything is fully fleshed out and answerable, don't hesitate to ask, give suggestion, say if you have an interest or disinterest in any particular part, any strengths or weaknesses. 

Again, to wrap it all up briefly: I think it's very possible and not requiring an unrealistic amount of effort required to go the next level and indulge a star trek fan of a professor and blow this project out the water by doing all but physically taking him to some tv show shooting set. Bro can definitely dress the part, we'll even get him alil headset mic they use in star trek(idk if they use headsets, I never watched it.) and have him basically Spock-max. 
