# Conky per CachyOS + COSMIC (Wayland)

Guida completa per ricreare da zero questo pannello Conky su una nuova installazione di **CachyOS con COSMIC in sessione Wayland**. Il risultato è un pannello desktop in alto a destra con informazioni su CPU, RAM, GPU AMD, archiviazione e rete, font JetBrains Mono e sfondo ritagliato e sfocato con angoli a 90°.

Include inoltre un piccolo watcher: su COSMIC, dopo avere spento e riacceso un monitor, Conky può restare in esecuzione ma scomparire dal desktop. Il watcher lo riavvia in modo controllato e impedisce la creazione di istanze duplicate.

> Questa configurazione è pensata per **un singolo monitor** e per un pannello nell'angolo **in alto a destra**. Le sezioni [Adattamenti](#adattamenti-per-il-nuovo-pc) spiegano cosa cambiare su hardware o rete diversi.

## 1. Prerequisiti

1. Installa CachyOS scegliendo COSMIC come desktop environment, quindi accedi alla sessione **COSMIC (Wayland)**.
2. Apri il terminale e aggiorna il sistema:

   ```bash
   sudo pacman -Syu
   ```

3. Installa tutto ciò che serve a questa configurazione:

   ```bash
   sudo pacman -S --needed conky lm_sensors imagemagick iw networkmanager ttf-jetbrains-mono git
   ```

   I componenti già presenti in CachyOS (`systemd`, `journalctl`, `flock`, `ip`, `awk`, `sed` e `find`) non richiedono installazione aggiuntiva.

4. Verifica che Conky abbia il supporto necessario e che JetBrains Mono sia disponibile:

   ```bash
   conky -v
   fc-match 'JetBrains Mono'
   ```

   Nell'output di `conky -v` devono comparire Wayland, Lua e Cairo/Imlib2. Il secondo comando deve restituire un file JetBrains Mono.

5. Verifica i sensori. Se `sensors` non mostra temperature, esegui prima `sudo sensors-detect`, accetta i moduli suggeriti, riavvia e ripeti il test.

   ```bash
   sensors
   ```

## 2. File che compongono il setup

Il repository contiene tutti i file sorgente da conservare nel backup:

```text
~/.config/conky/
├── conky.conf                    # layout e valori mostrati dal pannello
├── conky-display-watch.sh        # avvio e ripristino dopo monitor off/on
├── conky-blur-background.sh      # crea il ritaglio sfocato del wallpaper
├── conky-blur-background.lua     # disegna il ritaglio con angoli arrotondati
├── autostart/
│   └── conky.desktop             # modello della voce di autostart
├── README.md
└── .gitignore

~/.config/autostart/
└── conky.desktop                 # copia attiva della voce di autostart
```

La cartella `~/.config/conky/cache/` **non va copiata**: contiene immagini temporanee del blur e viene ricreata automaticamente.

Non eliminare mai tutta `~/.config/autostart/`: può contenere voci di avvio di altre applicazioni. In questa guida si crea o si aggiorna solamente `~/.config/autostart/conky.desktop`.

## 3. Installazione da repository Git

Su un sistema nuovo, questi comandi scaricano i file esatti della configurazione in `~/.config/conky`:

```bash
mkdir -p ~/.config
git clone https://github.com/miketester10/conky-config.git ~/.config/conky
mkdir -p ~/.config/autostart
install -m 644 ~/.config/conky/autostart/conky.desktop ~/.config/autostart/conky.desktop
chmod 755 ~/.config/conky/conky-display-watch.sh ~/.config/conky/conky-blur-background.sh
```

Se la cartella `~/.config/conky` esiste già perché hai copiato i file da un backup, **non eseguire `git clone` sopra di essa**. Passa alla sezione seguente.

## 4. Installazione da backup o chiavetta USB

Supponiamo di avere una copia di questa cartella in `/percorso/del/backup/conky`. Crea le directory di destinazione e copia i file:

```bash
mkdir -p ~/.config/conky ~/.config/autostart
cp /percorso/del/backup/conky/conky.conf ~/.config/conky/
cp /percorso/del/backup/conky/conky-display-watch.sh ~/.config/conky/
cp /percorso/del/backup/conky/conky-blur-background.sh ~/.config/conky/
cp /percorso/del/backup/conky/conky-blur-background.lua ~/.config/conky/
cp /percorso/del/backup/conky/autostart/conky.desktop ~/.config/autostart/conky.desktop
chmod 755 ~/.config/conky/conky-display-watch.sh ~/.config/conky/conky-blur-background.sh
```

Sostituisci `/percorso/del/backup/conky` con il percorso reale, per esempio `/run/media/mike/USB/conky`.

### Contenuto obbligatorio della voce autostart

Il file `~/.config/autostart/conky.desktop` deve contenere esattamente:

```ini
[Desktop Entry]
Type=Application
Name=Conky display watcher
Comment=Restarts Conky after a COSMIC display configuration change
Exec=sh -c "$HOME/.config/conky/conky-display-watch.sh"
StartupNotify=false
Terminal=false
Icon=conky-logomark-violet
Categories=System;Monitor;
```

Gli altri tre script e `conky.conf` vanno copiati dal repository/backup senza riscriverli manualmente: sono i file sorgente completi del setup e devono rimanere nei percorsi indicati sopra.

## 5. Primo avvio e controllo

L'autostart `.desktop` viene convertito da systemd in un servizio utente. Per avviarlo subito, senza uscire dalla sessione COSMIC:

```bash
systemctl --user daemon-reload
systemctl --user restart app-conky@autostart.service
```

Controlla stato e processi:

```bash
systemctl --user status app-conky@autostart.service
pgrep -af '(^|/)conky( |$)'
```

Deve esserci un solo processo Conky, avviato con `--config /home/<utente>/.config/conky/conky.conf`. Al login successivo partirà automaticamente grazie a `~/.config/autostart/conky.desktop`; non è necessario abilitare manualmente un servizio systemd.

Per vedere i messaggi del watcher in tempo reale:

```bash
journalctl --user -u app-conky@autostart.service -f
```

Per fermare temporaneamente il pannello:

```bash
systemctl --user stop app-conky@autostart.service
```

Per riavviarlo dopo modifiche a script, autostart o configurazione:

```bash
systemctl --user restart app-conky@autostart.service
```

## 6. Perché serve il watcher del monitor

`conky-display-watch.sh` mantiene Conky in primo piano come processo figlio (per questo in `conky.conf` `background = false`). Ascolta il journal utente di `cosmic-comp`; quando COSMIC ricrea un output dopo lo spegnimento/riaccensione del monitor, attende un secondo e sostituisce la vecchia istanza Conky.

Il lock con `flock` consente un solo watcher. Il debounce di otto secondi evita che più messaggi della stessa riconfigurazione producano più processi Conky. Questa parte è specifica per COSMIC: se in futuro COSMIC cambia i messaggi di log, cerca gli eventi con:

```bash
journalctl --user -b -o cat _COMM=cosmic-comp
```

e aggiorna il blocco `case` in `conky-display-watch.sh` solo se il problema ricompare.

## 7. Sfondo blur

Lo sfondo non usa X11 né trasparenza gestita dal compositor. Lo script `conky-blur-background.sh`:

1. legge il wallpaper corrente da `~/.config/cosmic/com.system76.CosmicBackground/v1/all`;
2. legge risoluzione e scala dell'output da `cosmic-randr list`;
3. ritaglia la porzione del wallpaper dietro il pannello;
4. la sfoca con ImageMagick e la salva in `~/.config/conky/cache/blurred-background.png`;
5. `conky-blur-background.lua` la disegna come rettangolo a 90° senza clipping.

Al primo avvio il watcher crea la cache. In seguito Lua controlla il wallpaper una volta al minuto: se cambia, lo script rigenera la cache e ricarica Conky.

| Elemento | File | Valore attuale |
| --- | --- | --- |
| Larghezza pannello | `conky.conf` e script blur | `340` px |
| Distanza da destra | `conky.conf` e script blur | `gap_x = 30` px |
| Distanza dall'alto | `conky.conf` e script blur | `gap_y = 40` px |
| Altezza area del blur | script blur | `1100` px |
| Intensità blur | script blur | `blur_sigma=20` |
| Velatura | script blur | `brightness=-6` |
| Angoli | Lua | `90°` (rettangolo, senza clipping) |

Per cambiare l'intensità del blur modifica in `~/.config/conky/conky-blur-background.sh` questa riga:

```bash
blur_sigma=20
```

Valori maggiori sfocano di più; prova ad esempio `8`, `16` o `20`. Per ridurre o aumentare la velatura modifica `brightness=-6`: valori più negativi sono più scuri. Dopo una modifica rigenera e riavvia:

```bash
~/.config/conky/conky-blur-background.sh
systemctl --user restart app-conky@autostart.service
```

Se cambi `maximum_width`, `minimum_width`, `gap_x` o `gap_y` in `conky.conf`, cambia gli stessi valori all'inizio dello script blur. Se il monitor è più basso di 1140 px logici, riduci anche `panel_height=1100` a un valore che lasci spazio per `gap_y`. Il pannello deve restare in `alignment = 'top_right'`: lo script calcola il ritaglio specificamente per quella posizione.

## 8. Adattamenti per il nuovo PC

### Rete

La configurazione usa l'interfaccia Wi-Fi `wlan0`. Trova quella del nuovo PC:

```bash
ip -br link
nmcli device status
```

Sostituisci **tutte e sette** le occorrenze di `wlan0` in `~/.config/conky/conky.conf` con il nome corretto, ad esempio `wlp2s0`. Le righe interessate sono Download, grafico Download, Upload, grafico Upload, IP locale, Canale Wi-Fi e DNS.

Se usi Ethernet, inserisci il nome dell'interfaccia (ad esempio `enp3s0`). La riga del canale mostrerà correttamente `No Channel`, perché non esiste un canale Wi-Fi su Ethernet.

### CPU e sensori

Questa configurazione mostra la temperatura `Tctl`, comune su CPU AMD Ryzen, e la massima frequenza corrente trovata fra tutti i core tramite `scaling_cur_freq`. Controlla il tuo output:

```bash
sensors
find /sys/devices/system/cpu/cpu*/cpufreq -name scaling_cur_freq -print
```

Su CPU Intel o su sensori con un nome diverso da `Tctl`, modifica questa parte di `conky.conf`:

```lua
${execi 1 sensors | awk '/^Tctl:/ {print $2; exit}' | tr -d '+'}
```

Sostituisci `Tctl` con la label che compare sul tuo sistema, per esempio `Package id 0`. Anche Governor ed EPP possono non essere presenti su ogni CPU: se producono una riga vuota, puoi adattarli o rimuoverli.

### GPU

La sezione attuale è pensata per AMDGPU/Radeon 780M. Prima di modificare i percorsi, individua i file esposti dalla tua GPU:

```bash
find /sys/class/drm -path '*device*' \( -name gpu_busy_percent -o -name mem_info_vram_used -o -name mem_info_vram_total -o -name power1_average \) 2>/dev/null
sensors
```

In particolare `Power` usa un percorso specifico `/sys/class/drm/card1/device/hwmon/hwmon2/power1_average`; sul nuovo PC trova il percorso restituito da `find` e sostituiscilo. Cambia anche il titolo `GPU (Radeon 780M)` e il sensore `edge` se necessario. GPU NVIDIA o Intel richiedono comandi differenti: puoi rimuovere temporaneamente le righe GPU finché non sono adattate.

## 9. Frequenza di aggiornamento e impatto

`update_interval = 1` aggiorna Conky ogni secondo. I valori principali che cambiano rapidamente sono aggiornati ogni secondo: uso CPU e barra CPU, frequenza massima CPU, RAM usata e barra RAM, temperatura CPU, uso/potenza/frequenza/VRAM/temperatura GPU, barra VRAM, barra Root e traffico/grafici di rete.

I valori più statici sono aggiornati ogni 10 secondi: RAM totale, Governor, EPP, VRAM totale, spazio Root, canale Wi-Fi e DNS. Kernel è fornito direttamente da Conky e viene ridisegnato con il ciclo di un secondo.

Il carico è molto basso per un PC moderno. Le operazioni più costose sono `sensors` e le letture periodiche in `/sys`; il blur non viene ricreato a ogni frame ma solo al primo avvio o dopo un cambio wallpaper/ridimensionamento.

## 10. Diagnostica rapida

Verifica la sintassi degli script:

```bash
bash -n ~/.config/conky/conky-display-watch.sh
bash -n ~/.config/conky/conky-blur-background.sh
```

Rigenera manualmente il blur e controlla che sia stato creato:

```bash
~/.config/conky/conky-blur-background.sh
identify ~/.config/conky/cache/blurred-background.png
```

Se il pannello non appare:

```bash
systemctl --user restart app-conky@autostart.service
journalctl --user -u app-conky@autostart.service -n 100 --no-pager
```

Se dopo prove manuali trovi vecchie istanze Conky, ferma il servizio, chiudi solo i processi `conky` dell'utente e riavvia il servizio:

```bash
systemctl --user stop app-conky@autostart.service
pkill -x conky
systemctl --user start app-conky@autostart.service
```
