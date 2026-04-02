#!/bin/bash
printf 'Status: 403 Forbidden\r\n'
printf 'Content-Type: application/json\r\n'
printf 'Cache-Control: no-store\r\n'
printf '\r\n'
printf '{"error":"Tunnel status endpoint disabled for security."}\n'
