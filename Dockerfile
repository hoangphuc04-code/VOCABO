FROM nginx:alpine

# Copy toàn bộ thư mục web vào nginx html root
COPY web/ /usr/share/nginx/html/

# Copy nginx config tùy chỉnh
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
