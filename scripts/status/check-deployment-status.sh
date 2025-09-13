#!/bin/bash
echo "UNALIVE" > status.txt
echo '{"status":"UNALIVE","timestamp":"'2025-09-13T20:43:59Z'","project_id":"cataziza-platform-dev","region":"europe-west1","last_checked":"'2025-09-13 20:43:59 UTC'"}' > deployment-status.json
echo "Status check completed - UNALIVE"
