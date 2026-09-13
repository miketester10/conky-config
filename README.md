# Conky per COSMIC / Wayland

Questa configurazione mostra CPU, RAM, temperatura, GPU AMD, VRAM, spazio disco e traffico di rete in un pannello Conky posizionato in alto a destra.

Include anche un watcher per COSMIC: quando il monitor viene spento e riacceso, COSMIC può rimuovere la superficie desktop di Conky pur lasciando il processo attivo. Lo script rileva il ripristino dell'output nei log di `cosmic-comp` e riavvia Conky, mantenendo una sola istanza attiva.

## Requisiti

Il setup è pensato per Linux con:

- sessione **COSMIC su Wayland**;
- `conky` con supporto Wayland;
- `systemd` e `journalctl`;
- `flock` (normalmente fornito da `util-linux`);
- `lm-sensors` per le temperature.

Su distribuzioni Debian/Ubuntu/Pop!_OS:

```bash
sudo apt install conky-all lm-sensors
```

La parte GPU è stata scritta per una Radeon 780M con driver AMDGPU. Su altra GPU alcuni comandi in `conky.conf` devono essere adattati o rimossi.

## File inclusi

```text
conky/
├── conky.conf
├── conky-display-watch.sh
└── autostart/
    └── conky.desktop
```

Una volta installati, i file devono trovarsi qui:

```text
~/.config/conky/conky.conf
~/.config/conky/conky-display-watch.sh
~/.config/autostart/conky.desktop
```

La cartella `~/.config/autostart` può contenere anche le voci di avvio di altre applicazioni. Non eliminare l'intera cartella: crea o aggiorna soltanto il file `conky.desktop`.

## Installazione su un altro PC

1. Copia questa cartella su un supporto esterno oppure clona il repository.

2. Dalla cartella copiata, installa i file:

```bash
mkdir -p ~/.config/conky ~/.config/autostart
cp conky.conf conky-display-watch.sh ~/.config/conky/
cp autostart/conky.desktop ~/.config/autostart/conky.desktop
chmod +x ~/.config/conky/conky-display-watch.sh
```

3. Esci e rientra nella sessione COSMIC. Conky partirà automaticamente.

Per attivarlo subito senza disconnettersi:

```bash
systemctl --user daemon-reload
systemctl --user restart app-conky@autostart.service
```

## Cosa contiene l'autostart

Il file `~/.config/autostart/conky.desktop` avvia:

```text
$HOME/.config/conky/conky-display-watch.sh
```

Il watcher avvia Conky usando `conky.conf`, poi resta in ascolto dei messaggi di COSMIC relativi alla riconfigurazione del monitor. Al rilevamento dell'evento aspetta un secondo, chiude l'istanza precedente e ne crea una nuova. Un lock impedisce l'avvio di due watcher contemporaneamente e l'intervallo di otto secondi evita riavvii duplicati per lo stesso evento.

Nel file `conky.conf`, `background` deve restare impostato a `false`: il watcher deve poter mantenere il PID di Conky per chiuderlo prima di ogni riavvio.

## Adattamenti richiesti su altro hardware

### Interfaccia di rete

La configurazione usa `wlan0`. Per trovare il nome corretto:

```bash
ip -br link
```

Sostituisci `wlan0` nelle quattro righe `downspeed`, `downspeedgraph`, `upspeed` e `upspeedgraph` di `conky.conf`. Nomi comuni sono `wlp2s0`, `enp3s0` o `eno1`.

### GPU AMD

La sezione GPU legge file in `/sys/class/drm/card*/device/`. Il nome visualizzato `Radeon 780M`, il percorso dell'alimentazione e i sensori possono essere diversi su un altro PC. Se una riga mostra un valore vuoto, individua il file disponibile con:

```bash
find /sys/class/drm -path '*device*' \( -name gpu_busy_percent -o -name mem_info_vram_used -o -name mem_info_vram_total -o -name power1_average \) 2>/dev/null
sensors
```

Su GPU NVIDIA o Intel è necessario riscrivere o rimuovere la sezione GPU.

### Posizione e dimensioni

Nella parte iniziale di `conky.conf` puoi modificare:

- `alignment = 'top_right'` per l'angolo del pannello;
- `gap_x` e `gap_y` per la distanza dai bordi;
- `maximum_width` e `minimum_width` per la larghezza;
- `font` per il font e la dimensione.

## Verifica e gestione

Controlla che Conky sia attivo:

```bash
pgrep -af conky
systemctl --user status app-conky@autostart.service
```

Deve esserci una sola riga del processo `conky`. Per riavviare il setup dopo una modifica allo script o alla voce autostart:

```bash
systemctl --user restart app-conky@autostart.service
```

Per fermarlo temporaneamente:

```bash
systemctl --user stop app-conky@autostart.service
```

## Limite del watcher

Il watcher cerca messaggi specifici di `cosmic-comp`; è quindi una soluzione mirata a COSMIC e al problema del monitor che scompare. Su GNOME, KDE, Hyprland o altri compositor la sezione relativa al watcher potrebbe non essere necessaria oppure richiedere un trigger differente.
