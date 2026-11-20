-- Required by the /v1/sync/devices/register upsert.
CREATE UNIQUE INDEX IF NOT EXISTS sync_devices_user_device_uq ON sync_devices(user_id, device_key);
