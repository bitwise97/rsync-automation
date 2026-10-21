# Frame Sync

A small shell script that keeps a local folder in sync with a folder on a server, using rsync over SSH. It was written to refresh the videos on Raspberry Pi digital photo frames each night, but works for any folder.

Files added on the server are copied down, and files removed from the server are removed locally, so the local folder mirrors the server.

## Requirements

- **rsync** installed on both machines
- **SSH key authentication** from the client to the server. The script runs unattended, so SSH must connect without a password prompt.
- The source folder must be a **mounted filesystem** on the server (for example, a NAS share). The script refuses to run otherwise.

## Setup

1. Copy `rsync.sh` and `rsync.conf` into the same folder on the client, for example `/home/pi/frame/`.
2. On `rsync.conf`fill in your values:
```sh
   SERVER="192.168.1.100"          # server address
   SRC_DIR="/mnt/MEDIA"            # folder on the server (a mount point)
   DEST="/home/pi/frame/videos/"   # local folder to mirror into
   EXCLUDES="@Recycle"             # names to skip, space-separated
```
3. Make the script executable:
```sh
   chmod +x rsync.sh
```
4. Test it by hand:
```sh
   ./rsync.sh
```
5. Schedule it with cron (`crontab -e`), for example nightly at 1:30 AM, with a report emailed to you:
```
   MAILTO="you@example.com"
   30 1 * * * /home/pi/frame/rsync.sh
```
   Email delivery requires a mail tool such as msmtp to be configured on the client.

## Warning

The sync **deletes** anything in `DEST` that is not on the server. Use a folder dedicated to the synced files, never a folder holding anything else.

## Safeguards

- **Mount check:** if the source folder is not mounted on the server, the sync aborts. An unmounted share looks like an empty folder, and mirroring it would delete the local copy.
- **Retries:** connection failures are retried up to 5 times, a minute apart.
- **Resumable transfers:** interrupted files are kept in a hidden `.rsync-partial` folder and resumed on the next attempt rather than restarted.
- **Deletion limit:** a single run deletes at most 100 files.
- **Config validation:** the script aborts if `sync.conf` is missing or incomplete.

## Output

Each run prints the start time, the files deleted and transferred, a short summary, and the result of each attempt. Under cron, this output arrives as the email report. The script exits with rsync's final exit code (0 means success).

## License

MIT. See `LICENSE`.
