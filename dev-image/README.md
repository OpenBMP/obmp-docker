OpenBMP Development Image
----------------------------
This image is the base development image used to build all the OpenBMP
components. It has all the needed dependencies included.

### Build Image

```
docker build -t openbmp/dev-image:build-NNN .
```

### Publish Image to dockerhub

```
# Login to docker
docker login

# Tag the image
docker tag openbmp/dev-image:build-NNN openbmp/dev-image:latest

# Upload the image
docker push openbmp/dev-image:build-NNN
docker push openbmp/dev-image:latest
```
