-- +along Up
ALTER TABLE push_devices
    DROP CONSTRAINT push_devices_device_install_id_fkey;

ALTER TABLE device_installs
    DROP CONSTRAINT device_installs_pkey,
    ADD PRIMARY KEY (id, account_id);

DELETE FROM push_devices p
WHERE NOT EXISTS (
    SELECT 1
    FROM device_installs d
    WHERE d.id = p.device_install_id
      AND d.account_id = p.account_id
);

ALTER TABLE push_devices
    ADD CONSTRAINT push_devices_device_install_id_account_id_fkey
    FOREIGN KEY (device_install_id, account_id)
    REFERENCES device_installs(id, account_id) ON DELETE CASCADE;

-- +along Down
ALTER TABLE push_devices
    DROP CONSTRAINT push_devices_device_install_id_account_id_fkey;

ALTER TABLE device_installs
    DROP CONSTRAINT device_installs_pkey,
    ADD PRIMARY KEY (id);

ALTER TABLE push_devices
    ADD FOREIGN KEY (device_install_id)
    REFERENCES device_installs(id) ON DELETE CASCADE;