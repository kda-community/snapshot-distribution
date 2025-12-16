# Kadena Snapshot distribution server

These scripts works on a Debian 12 with ZFS enabled.

We assume the following:
- A user called Kadena owns the databases and the nodes
- RocksDB databases et Pact databases are 2 ZFS partitions mounted on `/live/0/rocksDB` and `/live/0/sqlite`


### Content of the repository

#### `/chainweb`

Chainweb config file

#### `/scripts`

Scripts files to be dropped in /usr/local/bin

`snapshot_fcts.sh`: contains common functions
`do_snapshot.sh`: Create a snapshot at the current data
`clean_snaphots.sh`: Clean old snapshots
`build_md.py`: Build the index.md

#### `/systemd`

Systemd unit files

#### `/nginx`

Nginx site config file. To be dropped in /etc/nginx/sites-enabled

#### `/html`

HTML static files. To be dropped in /var/www/html

#### `/rsync`

Rsyncd config file. To be dropped in /etc