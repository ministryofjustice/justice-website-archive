apiVersion: v1
kind: Secret
metadata:
  name: basic-auth
data:
  auth: ${BASIC_AUTH}
