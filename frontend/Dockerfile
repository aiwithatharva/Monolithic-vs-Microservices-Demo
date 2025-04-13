# /frontend/Dockerfile

# Use the official Nginx image from Docker Hub
FROM nginx:stable-alpine

# Remove the default Nginx configuration file
RUN rm /etc/nginx/conf.d/default.conf

# Copy our custom Nginx configuration file
COPY nginx.conf /etc/nginx/nginx.conf

# Copy the static frontend files (HTML, JS) into the Nginx serve directory
COPY index.html /usr/share/nginx/html/
COPY script.js /usr/share/nginx/html/
# Add any CSS file here if you have one:
# COPY style.css /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Default command to start Nginx when the container launches
CMD ["nginx", "-g", "daemon off;"]