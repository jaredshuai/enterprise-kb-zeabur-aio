.PHONY: full-init full-up full-down full-status full-backup paperless-admin

full-init:
	bash scripts/full-init.sh

full-up:
	bash scripts/full-up.sh

full-down:
	bash scripts/full-down.sh

full-status:
	bash scripts/full-status.sh

full-backup:
	bash scripts/full-backup.sh

paperless-admin:
	bash scripts/paperless-create-admin.sh
