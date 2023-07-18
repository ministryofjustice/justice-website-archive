apiVersion: apps/v1
kind: Deployment
metadata:
  name: justice-website-archive-dev
spec:
  replicas: 2
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%
  selector:
    matchLabels:
      app: justice-website-archive-dev
  template:
    metadata:
      labels:
        app: justice-website-archive-dev
    spec:
      containers:
      - name: justice-website-archive
        image: ${ECR_URL}:${IMAGE_TAG}
        ports:
        - containerPort: 8080
        env:
          - name: S3_BUCKET_NAME
            valueFrom:
              secretKeyRef:
                name: s3-bucket-output
                key: bucket_name
          - name: S3_ACCESS_KEY_ID
            valueFrom:
              secretKeyRef:
                name: s3-bucket-output
                key: access_key_id
          - name: S3_SECRET_ACCESS_KEY
            valueFrom:
              secretKeyRef:
                name: s3-bucket-output
                key: secret_access_key
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 15