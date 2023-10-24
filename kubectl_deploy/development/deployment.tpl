apiVersion: apps/v1
kind: Deployment
metadata:
  name: justice-archiver-dev
spec:
  replicas: 1
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 100%
  selector:
    matchLabels:
      app: justice-archiver-dev
  template:
    metadata:
      labels:
        app: justice-archiver-dev
    spec:
      serviceAccountName: justice-archiver-dev
      containers:
      - name: justice-archiver-dev
        image: ${ECR_URL}:${IMAGE_TAG}
        ports:
        - containerPort: 8080
        env:
          - name: S3_BUCKET_NAME
            valueFrom:
              secretKeyRef:
                name: s3-bucket-output
                key: bucket_name
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
