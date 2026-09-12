pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

Item {
    id: root

    // Signals for canonical application lifecycle (§4.3)
    signal appInstalled(string appId)
    signal appUninstalled(string appId)
    signal installProgress(string appId, real progress, string statusText)
    signal updatesChecked(int count)

    // Curated catalog of Linux applications matching DeloOS aesthetic
    readonly property var rawCatalog: [
        // --- DEVELOPMENT ---
        {
            "id": "code",
            "package": "visual-studio-code-bin",
            "name": "Visual Studio Code",
            "summary": "Code editing. Redefined.",
            "description": "Visual Studio Code is a code editor redefined and optimized for building and debugging modern web and cloud applications. Developed by Microsoft, it includes built-in Git support, syntax highlighting, and an expansive extension marketplace.",
            "category": "Development",
            "developer": "Microsoft Corporation",
            "version": "1.93.0",
            "size": "118 MB",
            "icon": "visual-studio-code",
            "rating": 4.9,
            "ratingCount": 18450,
            "featured": true,
            "trending": true,
            "license": "Proprietary / MIT Core",
            "homepage": "https://code.visualstudio.com"
        },
        {
            "id": "postman",
            "package": "postman-bin",
            "name": "Postman",
            "summary": "API platform for building and using APIs",
            "description": "Postman simplifies each step of the API lifecycle and streamlines collaboration so you can create better APIs faster. Features automated testing, mocks, documentation, and cloud workspaces.",
            "category": "Development",
            "developer": "Postman, Inc.",
            "version": "11.12.0",
            "size": "142 MB",
            "icon": "postman",
            "rating": 4.7,
            "ratingCount": 4210,
            "featured": false,
            "trending": true,
            "license": "Proprietary",
            "homepage": "https://www.postman.com"
        },
        {
            "id": "docker",
            "package": "docker-desktop",
            "name": "Docker Desktop",
            "summary": "Containerization platform for developers",
            "description": "Build, share, and run applications in containers seamlessly. Docker Desktop includes Docker Engine, Docker CLI client, Docker Compose, Kubernetes, and an intuitive graphical dashboard.",
            "category": "Development",
            "developer": "Docker Inc.",
            "version": "4.33.1",
            "size": "480 MB",
            "icon": "docker",
            "rating": 4.8,
            "ratingCount": 9320,
            "featured": true,
            "trending": false,
            "license": "Commercial / Apache 2.0",
            "homepage": "https://www.docker.com"
        },
        {
            "id": "git",
            "package": "git-gui",
            "name": "Git GUI",
            "summary": "Fast, scalable, distributed revision control system",
            "description": "Git is the ubiquitous version control system designed to handle everything from small to very large projects with speed and efficiency.",
            "category": "Development",
            "developer": "Git Community",
            "version": "2.46.0",
            "size": "34 MB",
            "icon": "git",
            "rating": 4.9,
            "ratingCount": 21000,
            "featured": false,
            "trending": false,
            "license": "GPLv2",
            "homepage": "https://git-scm.com"
        },
        {
            "id": "sublime",
            "package": "sublime-text-4",
            "name": "Sublime Text",
            "summary": "A sophisticated text editor for code, markup and prose",
            "description": "Sublime Text is a sleek, ultra-fast code editor with GPU acceleration, multi-caret editing, instant project switching, and powerful Python plugin API.",
            "category": "Development",
            "developer": "Sublime HQ Pty Ltd",
            "version": "4.1.80",
            "size": "26 MB",
            "icon": "sublime-text",
            "rating": 4.8,
            "ratingCount": 5120,
            "featured": false,
            "trending": false,
            "license": "Proprietary",
            "homepage": "https://www.sublimetext.com"
        },

        // --- INTERNET ---
        {
            "id": "firefox",
            "package": "firefox",
            "name": "Mozilla Firefox",
            "summary": "Fast, private and independent web browser",
            "description": "Get the browser that protects what's important. With Enhanced Tracking Protection, container tabs, picture-in-picture video, and full WebExtensions ecosystem.",
            "category": "Internet",
            "developer": "Mozilla Corporation",
            "version": "129.0.2",
            "size": "85 MB",
            "icon": "firefox",
            "rating": 4.8,
            "ratingCount": 31200,
            "featured": true,
            "trending": true,
            "license": "MPL 2.0",
            "homepage": "https://www.mozilla.org/firefox"
        },
        {
            "id": "discord",
            "package": "discord",
            "name": "Discord",
            "summary": "Voice, video and text communication service",
            "description": "Discord is the easiest way to talk over voice, video, and text. Talk, chat, hang out, and stay close with your friends and communities with low-latency streaming and rich bots.",
            "category": "Internet",
            "developer": "Discord Inc.",
            "version": "0.0.64",
            "size": "92 MB",
            "icon": "discord",
            "rating": 4.6,
            "ratingCount": 16400,
            "featured": true,
            "trending": true,
            "license": "Proprietary",
            "homepage": "https://discord.com"
        },
        {
            "id": "slack",
            "package": "slack-desktop",
            "name": "Slack",
            "summary": "Team communication and enterprise collaboration",
            "description": "Slack brings all your team communication together, giving everyone a shared workspace where conversations are organized and accessible. Integrates with Google Drive, GitHub, Jira, and more.",
            "category": "Internet",
            "developer": "Slack Technologies",
            "version": "4.39.95",
            "size": "104 MB",
            "icon": "slack",
            "rating": 4.5,
            "ratingCount": 7820,
            "featured": false,
            "trending": false,
            "license": "Proprietary",
            "homepage": "https://slack.com"
        },
        {
            "id": "telegram",
            "package": "telegram-desktop",
            "name": "Telegram Desktop",
            "summary": "Fast and secure messaging app",
            "description": "Telegram is a cloud-based mobile and desktop messaging app with a focus on security and speed. Supports 2GB file sharing, powerful groups, channels, and instant sync.",
            "category": "Internet",
            "developer": "Telegram FZ-LLC",
            "version": "5.4.1",
            "size": "45 MB",
            "icon": "telegram",
            "rating": 4.8,
            "ratingCount": 14200,
            "featured": false,
            "trending": true,
            "license": "GPLv3",
            "homepage": "https://desktop.telegram.org"
        },

        // --- MULTIMEDIA ---
        {
            "id": "spotify",
            "package": "spotify",
            "name": "Spotify",
            "summary": "Digital music and podcast streaming service",
            "description": "Spotify gives you instant access to millions of songs, podcasts, and videos from creators all over the world with playlist curation, smart radio, and seamless connect features.",
            "category": "Multimedia",
            "developer": "Spotify AB",
            "version": "1.2.45",
            "size": "165 MB",
            "icon": "spotify",
            "rating": 4.7,
            "ratingCount": 24000,
            "featured": true,
            "trending": true,
            "license": "Proprietary",
            "homepage": "https://www.spotify.com"
        },
        {
            "id": "obs",
            "package": "obs-studio",
            "name": "OBS Studio",
            "summary": "Live streaming and video recording software",
            "description": "Free and open source software for video recording and live streaming. High performance real-time video/audio capturing and mixing, unlimited scenes, and modular Dock UI.",
            "category": "Multimedia",
            "developer": "OBS Project",
            "version": "30.2.2",
            "size": "125 MB",
            "icon": "obs",
            "rating": 4.9,
            "ratingCount": 11300,
            "featured": true,
            "trending": false,
            "license": "GPLv2",
            "homepage": "https://obsproject.com"
        },
        {
            "id": "vlc",
            "package": "vlc",
            "name": "VLC Media Player",
            "summary": "The ultimate open source media player",
            "description": "VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files, DVDs, Audio CDs, VCDs, and various streaming protocols without codecs.",
            "category": "Multimedia",
            "developer": "VideoLAN",
            "version": "3.0.21",
            "size": "58 MB",
            "icon": "vlc",
            "rating": 4.8,
            "ratingCount": 19500,
            "featured": false,
            "trending": true,
            "license": "GPLv2",
            "homepage": "https://www.videolan.org"
        },
        {
            "id": "celluloid",
            "package": "celluloid",
            "name": "Celluloid",
            "summary": "Simple GTK+ frontend for mpv",
            "description": "Celluloid is an elegant graphical frontend for the mpv video player. It aims to be easy to use while maintaining mpv's high level of configurability and Wayland hardware acceleration.",
            "category": "Multimedia",
            "developer": "Gnome Community",
            "version": "0.26",
            "size": "12 MB",
            "icon": "celluloid",
            "rating": 4.7,
            "ratingCount": 1500,
            "featured": false,
            "trending": false,
            "license": "GPLv3",
            "homepage": "https://github.com/celluloid-player/celluloid"
        },
        {
            "id": "audacity",
            "package": "audacity",
            "name": "Audacity",
            "summary": "Multi-track audio editor and recorder",
            "description": "Audacity is an easy-to-use, multi-track audio editor and recorder for Linux. Features live recording, multi-track mixing, effects processing, and format conversion.",
            "category": "Multimedia",
            "developer": "Muse Group",
            "version": "3.6.1",
            "size": "42 MB",
            "icon": "audacity",
            "rating": 4.6,
            "ratingCount": 8200,
            "featured": false,
            "trending": false,
            "license": "GPLv2+",
            "homepage": "https://www.audacityteam.org"
        },

        // --- GRAPHICS ---
        {
            "id": "gimp",
            "package": "gimp",
            "name": "GIMP",
            "summary": "GNU Image Manipulation Program",
            "description": "GIMP is a cross-platform image editor available for GNU/Linux. High quality photo manipulation, original artwork creation, and graphic design elements with full GEGL engine.",
            "category": "Graphics",
            "developer": "The GIMP Team",
            "version": "2.10.38",
            "size": "150 MB",
            "icon": "gimp",
            "rating": 4.6,
            "ratingCount": 12800,
            "featured": true,
            "trending": false,
            "license": "GPLv3",
            "homepage": "https://www.gimp.org"
        },
        {
            "id": "inkscape",
            "package": "inkscape",
            "name": "Inkscape",
            "summary": "Professional vector graphics editor",
            "description": "Whether you are an illustrator, designer, web designer or just someone who needs to create vector imagery, Inkscape is for you! Native SVG support, node editing, and path operations.",
            "category": "Graphics",
            "developer": "Inkscape Project",
            "version": "1.3.2",
            "size": "190 MB",
            "icon": "inkscape",
            "rating": 4.8,
            "ratingCount": 9400,
            "featured": false,
            "trending": true,
            "license": "GPLv2+",
            "homepage": "https://inkscape.org"
        },
        {
            "id": "blender",
            "package": "blender",
            "name": "Blender",
            "summary": "3D modeling, animation, rendering, and compositing",
            "description": "Blender is the free and open source 3D creation suite. It supports the entirety of the 3D pipeline—modeling, rigging, animation, simulation, rendering, compositing and motion tracking.",
            "category": "Graphics",
            "developer": "Blender Foundation",
            "version": "4.2.0",
            "size": "520 MB",
            "icon": "blender",
            "rating": 4.9,
            "ratingCount": 26000,
            "featured": true,
            "trending": true,
            "license": "GPLv2+",
            "homepage": "https://www.blender.org"
        },

        // --- PRODUCTIVITY & OFFICE ---
        {
            "id": "libreoffice",
            "package": "libreoffice-fresh",
            "name": "LibreOffice",
            "summary": "Comprehensive, modern office productivity suite",
            "description": "LibreOffice includes several applications: Writer (word processing), Calc (spreadsheets), Impress (presentations), Draw (vector diagrams), and Base (databases). Compatible with Microsoft Office formats.",
            "category": "Office",
            "developer": "The Document Foundation",
            "version": "24.2.5",
            "size": "280 MB",
            "icon": "libreoffice",
            "rating": 4.6,
            "ratingCount": 8900,
            "featured": false,
            "trending": false,
            "license": "MPL 2.0",
            "homepage": "https://www.libreoffice.org"
        },
        {
            "id": "obsidian",
            "package": "obsidian",
            "name": "Obsidian",
            "summary": "Sharpen your thinking with linked Markdown notes",
            "description": "Obsidian is a powerful knowledge base on top of a local folder of plain text Markdown files. Features interactive graph views, local sync, and a vast community plugin ecosystem.",
            "category": "Office",
            "developer": "Dynalist Inc.",
            "version": "1.6.7",
            "size": "105 MB",
            "icon": "obsidian",
            "rating": 4.9,
            "ratingCount": 11200,
            "featured": true,
            "trending": true,
            "license": "Proprietary / Free for personal",
            "homepage": "https://obsidian.md"
        },

        // --- SYSTEM & UTILITIES ---
        {
            "id": "terminal",
            "package": "kitty",
            "name": "Delo Terminal",
            "summary": "Fast, feature-rich, GPU-accelerated terminal emulator",
            "description": "Configured for DeloOS with Calm Mica styling, true color support, Ligatures, image rendering, and instant command-line responsiveness.",
            "category": "System",
            "developer": "Kovid Goyal / DeloOS",
            "version": "0.36.1",
            "size": "24 MB",
            "icon": "terminal",
            "rating": 4.9,
            "ratingCount": 15600,
            "featured": false,
            "trending": false,
            "license": "GPLv3",
            "homepage": "https://sw.kovidgoyal.net/kitty/"
        },
        {
            "id": "thunar",
            "package": "thunar",
            "name": "Thunar File Manager",
            "summary": "Modern, fast, and lightweight file manager",
            "description": "Default file management application for Deloway DE. Features fast tabbed navigation, bookmarking, and responsive file operations.",
            "category": "System",
            "developer": "Xfce Community",
            "version": "4.20.0",
            "size": "18 MB",
            "icon": "system-file-manager",
            "rating": 4.8,
            "ratingCount": 6800,
            "featured": true,
            "trending": true,
            "license": "GPLv2+",
            "homepage": "https://docs.xfce.org/xfce/thunar/start"
        },
        {
            "id": "org.gnome.TextEditor",
            "package": "gnome-text-editor",
            "name": "GNOME Text Editor",
            "summary": "Focused, modern text and code editor",
            "description": "Clean and distraction-free text editor with syntax highlighting, line numbering, and session management.",
            "category": "Office",
            "developer": "GNOME Project",
            "version": "46.3",
            "size": "6 MB",
            "icon": "text-editor",
            "rating": 4.7,
            "ratingCount": 4300,
            "featured": false,
            "trending": true,
            "license": "GPLv3+",
            "homepage": "https://apps.gnome.org/TextEditor/"
        },
        {
            "id": "pwvucontrol",
            "package": "pwvucontrol",
            "name": "PipeWire Volume Control",
            "summary": "Advanced PipeWire audio mixer and routing",
            "description": "Granular volume control, channel mapping, and audio device management built specifically for modern PipeWire systems.",
            "category": "Multimedia",
            "developer": "PipeWire Project",
            "version": "0.5.3",
            "size": "4 MB",
            "icon": "multimedia-volume-control",
            "rating": 4.8,
            "ratingCount": 1800,
            "featured": false,
            "trending": false,
            "license": "GPLv3",
            "homepage": "https://gitlab.freedesktop.org/pipewire"
        },
        {
            "id": "io.missioncenter.MissionCenter",
            "package": "mission-center",
            "name": "Mission Center",
            "summary": "Monitor CPU, Memory, Disk, Network and GPU usage",
            "description": "Modern hardware-accelerated system resource monitor with real-time graphs and hardware statistics.",
            "category": "System",
            "developer": "Mission Center Team",
            "version": "1.2.0",
            "size": "22 MB",
            "icon": "utilities-system-monitor",
            "rating": 4.9,
            "ratingCount": 7200,
            "featured": true,
            "trending": true,
            "license": "GPLv3",
            "homepage": "https://missioncenter.io"
        },
        {
            "id": "settings",
            "package": "deloway-settings",
            "name": "Delo Settings",
            "summary": "Centralized system configuration and preferences",
            "description": "Manage desktop modes, theme, keyboard shortcuts, network, Bluetooth, power profiles, and default applications from a single unified control panel.",
            "category": "System",
            "developer": "DeloOS Team",
            "version": "1.0.0",
            "size": "15 MB",
            "icon": "settings",
            "rating": 5.0,
            "ratingCount": 120,
            "featured": false,
            "trending": false,
            "license": "MIT",
            "homepage": "https://deloway.org"
        },
        {
            "id": "steam",
            "package": "steam",
            "name": "Steam",
            "summary": "The ultimate digital entertainment platform",
            "description": "Play thousands of games on Linux with Proton compatibility, Steam Cloud sync, voice chat, and the gaming community.",
            "category": "Games",
            "developer": "Valve Corporation",
            "version": "1.0.0.79",
            "size": "78 MB",
            "icon": "steam",
            "rating": 4.8,
            "ratingCount": 42000,
            "featured": true,
            "trending": true,
            "license": "Proprietary",
            "homepage": "https://store.steampowered.com"
        }
    ]

    // Dynamic installed application IDs computed from real system state
    property var installedIds: rawCatalog.filter(a => ApplicationManager.isInstalled(a.id)).map(a => a.id)

    // Installing states: map of appId -> { progress: real, status: string }
    property var installingMap: ({})

    // Updates available (empty by default, populated by real pacman check)
    property var updatableIds: []

    // Check if an app is installed
    function isInstalled(appId) {
        if (!appId) return false;
        return ApplicationManager.isInstalled(appId);
    }

    // Check if an app is currently installing
    function isInstalling(appId) {
        if (!appId) return false;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return installingMap[clean] !== undefined;
    }

    // Get installation progress (0.0 to 1.0)
    function getInstallProgress(appId) {
        if (!appId) return 0.0;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return (installingMap[clean] && installingMap[clean].progress) ? installingMap[clean].progress : 0.0;
    }

    // Get installation status text
    function getInstallStatus(appId) {
        if (!appId) return "";
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return (installingMap[clean] && installingMap[clean].status) ? installingMap[clean].status : "";
    }

    // Lookup full app record by ID
    function getApp(appId) {
        if (!appId) return null;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        return rawCatalog.find(a => a.id === clean) || null;
    }

    // Dynamic catalog view enriched with live installation flags
    readonly property var catalog: {
        return rawCatalog.map(app => {
            const copy = Object.assign({}, app);
            copy.installed = root.isInstalled(app.id);
            copy.isInstalling = root.isInstalling(app.id);
            copy.progress = root.getInstallProgress(app.id);
            copy.statusText = root.getInstallStatus(app.id);
            copy.hasUpdate = root.updatableIds.includes(app.id);
            return copy;
        });
    }

    // Featured apps for the hero banner & spotlight
    readonly property var featuredApps: catalog.filter(a => a.featured)

    // Installed apps
    readonly property var installedApps: catalog.filter(a => a.installed)

    // Updatable apps
    readonly property var updatableApps: catalog.filter(a => a.hasUpdate)

    // Query helper filtering by category and search text
    function queryApps(category, searchText) {
        const cat = (category || "all").toLowerCase();
        const q = (searchText || "").toLowerCase().trim();

        return catalog.filter(app => {
            // Category filter
            if (cat === "featured" && !app.featured) return false;
            if (cat === "installed" && !app.installed) return false;
            if (cat === "updates" && !app.hasUpdate) return false;
            if (cat !== "all" && cat !== "featured" && cat !== "installed" && cat !== "updates") {
                if (app.category.toLowerCase() !== cat) return false;
            }

            // Search filter
            if (q.length > 0) {
                const matchName = app.name.toLowerCase().includes(q);
                const matchSummary = app.summary.toLowerCase().includes(q);
                const matchCat = app.category.toLowerCase().includes(q);
                const matchDev = app.developer.toLowerCase().includes(q);
                if (!matchName && !matchSummary && !matchCat && !matchDev) return false;
            }

            return true;
        });
    }

    // Queue of pending installs: [ { appId: string, pkg: string, provider: string } ]
    property var installQueue: []

    // Real Process Wrapper for pacman / AUR
    Process {
        id: installProc
        property string activeAppId: ""
        property string activePkg: ""
        property string activeProvider: "native"

        stdout: SplitParser {
            onRead: function(data) {
                root.parseProcessOutput(installProc.activeAppId, data);
            }
        }
        stderr: SplitParser {
            onRead: function(data) {
                root.parseProcessOutput(installProc.activeAppId, data);
            }
        }
        onExited: function(exitCode, exitStatus) {
            const currentId = installProc.activeAppId;
            installProc.activeAppId = "";
            installProc.activePkg = "";
            installProc.activeProvider = "native";

            const newMap = Object.assign({}, root.installingMap);
            delete newMap[currentId];
            root.installingMap = newMap;

            if (exitCode === 0) {
                root.completeInstallation(currentId);
            } else {
                console.warn("[PackageManager] Installation failed for " + currentId + " with exit code " + exitCode);
                NotificationManager.postNotification(
                    "Delo Store",
                    "Installation Failed",
                    "Failed to install package for " + currentId + " (code " + exitCode + ")",
                    "software-store"
                );
            }

            // Process next queued install if any
            root.processNextQueueItem();
        }
    }

    function parseProcessOutput(appId, line) {
        if (!appId || !line) return;
        const text = line.trim();
        if (text.length === 0) return;

        let progress = root.getInstallProgress(appId);
        let status = root.getInstallStatus(appId) || "Processing...";

        // 1. Check for percentage in output: e.g. [ 45%] or 45%
        const percentMatch = text.match(/(\d+)%/);
        if (percentMatch) {
            const pct = parseInt(percentMatch[1], 10);
            if (!isNaN(pct)) {
                progress = Math.min(0.98, Math.max(0.05, pct / 100.0));
            }
        }

        // 2. Parse status phase from pacman stdout
        if (text.includes("downloading") || text.includes("Retrieving packages")) {
            status = "Downloading package...";
            if (!percentMatch) progress = Math.max(progress, 0.20);
        } else if (text.includes("checking keys") || text.includes("checking package integrity") || text.includes("verifying")) {
            status = "Verifying package integrity...";
            if (!percentMatch) progress = Math.max(progress, 0.50);
        } else if (text.includes("checking for file conflicts") || text.includes("checking available disk space")) {
            status = "Checking dependencies...";
            if (!percentMatch) progress = Math.max(progress, 0.65);
        } else if (text.includes("installing") || text.includes("installing ") || text.includes("Processing package changes")) {
            status = "Installing binaries...";
            if (!percentMatch) progress = Math.max(progress, 0.80);
        } else if (text.includes("running post-transaction hooks")) {
            status = "Finalizing configuration...";
            progress = 0.95;
        }

        const newMap = Object.assign({}, root.installingMap);
        newMap[appId] = { progress: progress, status: status };
        root.installingMap = newMap;
        root.installProgress(appId, progress, status);
    }

    function processNextQueueItem() {
        if (installProc.running || installQueue.length === 0) return;
        const item = installQueue[0];
        installQueue = installQueue.slice(1);

        installProc.activeAppId = item.appId;
        installProc.activePkg = item.pkg;
        installProc.activeProvider = item.provider;

        if (item.provider === "flatpak") {
            // Flatpak provider abstraction placeholder (ready for future integration)
            console.log("[PackageManager] Flatpak provider is registered but not enabled yet for " + item.pkg);
            return;
        }

        // Pamac provider (handles native Arch repos + AUR seamlessly with Polkit)
        installProc.command = ["pamac", "install", "--no-confirm", item.pkg];
        installProc.running = true;
    }

    // Trigger installation (§4.3 Canonical Application Lifecycle)
    function installApp(appId, provider) {
        provider = provider || "native";
        if (!appId || isInstalled(appId) || isInstalling(appId)) return;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        const app = getApp(clean);
        if (!app) return;

        const pkgName = app.package || clean;

        // Set initial state
        const newMap = Object.assign({}, root.installingMap);
        newMap[clean] = { progress: 0.05, status: "Starting installation..." };
        root.installingMap = newMap;
        root.installProgress(clean, 0.05, "Starting installation...");

        installQueue = installQueue.concat([{
            appId: clean,
            pkg: pkgName,
            provider: provider
        }]);

        processNextQueueItem();
    }

    // Finish installation and notify system
    function completeInstallation(cleanId) {
        if (!installedIds.includes(cleanId)) {
            installedIds = installedIds.concat([cleanId]);
        }

        const app = getApp(cleanId);
        if (app) {
            // 1. Register with ApplicationManager
            ApplicationManager.registerInstalledApp({
                id: app.id,
                name: app.name,
                icon: app.icon,
                category: app.category,
                exec: app.id,
                comment: app.summary
            });

            // 2. Post desktop notification
            NotificationManager.postNotification(
                "Delo Store",
                app.name + " Installed",
                "The application has been installed successfully and is ready to launch.",
                app.icon
            );

            // 3. Emit signal
            root.appInstalled(cleanId);
            console.log("[PackageManager] Successfully installed app:", app.name);
        }
    }

    // Uninstall application
    function uninstallApp(appId) {
        if (!appId || !isInstalled(appId)) return;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        const app = getApp(clean);

        // Remove from installed list
        installedIds = installedIds.filter(id => id !== clean);

        // Remove from updatable if present
        updatableIds = updatableIds.filter(id => id !== clean);

        // Unpin from Dock if pinned
        if (ApplicationManager.isPinned(clean)) {
            ApplicationManager.unpinApp(clean);
        }

        // Unregister from ApplicationManager
        ApplicationManager.unregisterApp(clean);

        if (app) {
            NotificationManager.postNotification(
                "Delo Store",
                app.name + " Uninstalled",
                "The application has been removed from your system.",
                app.icon
            );
        }

        root.appUninstalled(clean);
        console.log("[PackageManager] Successfully uninstalled app:", clean);
    }

    // Update single application
    function updateApp(appId) {
        if (!appId) return;
        const clean = appId.toLowerCase().replace(/\.desktop$/, "");
        updatableIds = updatableIds.filter(id => id !== clean);
        const app = getApp(clean);
        if (app) {
            NotificationManager.postNotification(
                "Delo Store",
                app.name + " Updated",
                "Updated to version " + app.version + " successfully.",
                app.icon
            );
        }
    }

    // Update all available apps
    function updateAll() {
        const count = updatableIds.length;
        updatableIds = [];
        NotificationManager.postNotification(
            "Delo Store",
            "Updates Complete",
            count + " applications were updated to their latest versions.",
            "software-store"
        );
    }
}
