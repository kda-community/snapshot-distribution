# Kadena Snapshot distribution server

These scripts works on a Debian 12 with ZFS enabled.

We assume the following:
- A user called Kadena owns the databases and the nodes
- RocksDB databases et Pact databases are 2 ZFS partitions mounted on `/live/0/rocksDB` and `/live/0/sqlite`
