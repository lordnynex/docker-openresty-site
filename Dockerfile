FROM envygeeks/alpine
MAINTAINER Brandon Beveridge <lordnynex@phatlab.org>
COPY copy/ /
<% if (env = @metadata["env"].as_hash).any? %>
ENV <%= @metadata["env"].as_hash.to_env_ary.join(" ") %>
<% end %>
ENV \
  JEKYLL_GIT_URL=https://github.com/jekyll/jekyll.git \
  JEKYLL_VERSION=<%= @metadata.as_gem_version %>
RUN \
  echo "==> Installing dependencies..." \
  && apk --update add <%= @metadata["pkgs"].as_string_set %> \

  <% if @metadata["tag"] != "builder" %>
    && mkdir -p /root/ngx_openresty \
    && cd /root/ngx_openresty \
    && echo "==> Downloading OpenResty..." \
    && curl -sSL http://openresty.org/download/ngx_openresty-${OPENRESTY_VERSION}.tar.gz | tar -xvz \
    && cd ngx_openresty-* \
    && echo "==> Configuring OpenResty..." \
    && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
    && echo "using upto $NPROC threads" \
    && ./configure \
      --sbin-path=/usr/sbin/nginx \
      --pid-path=/var/run/nginx.pid \
      --lock-path=/var/lock/nginx.lock \
      --conf-path=/etc/nginx/nginx.conf \
      --http-client-body-temp-path=$VAR_PREFIX/client_body_temp \
      --http-proxy-temp-path=$VAR_PREFIX/proxy_temp \
      --http-log-path=$VAR_PREFIX/access.log \
      --error-log-path=$VAR_PREFIX/error.log \
      --pid-path=$VAR_PREFIX/nginx.pid \
      --lock-path=$VAR_PREFIX/nginx.lock \
      --with-luajit \
      --with-pcre-jit \
      --with-ipv6 \
      --with-http_ssl_module \
      -j${NPROC} \
    && echo "==> Building OpenResty..." \
    && make -j${NPROC} \
    && echo "==> Installing OpenResty..." \
    && make install \
    && echo "==> Finishing..." \
    && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* $OPENRESTY_PREFIX/luajit/bin/lua \
    && ln -sf $OPENRESTY_PREFIX/luajit/bin/luajit-* /usr/local/bin/lua \
    && rm -rf /root/ngx_openresty \
    && mv /etc/nginx/conf.d /tmp/nginx.conf.d \
    && rm -rf /etc/nginx && cd /tmp && git clone https://github.com/envygeeks/docker.git \
    && cp -R docker/dockerfiles/nginx/copy/etc/startup3.d/nginx /etc/startup3.d \
    && cp -R docker/dockerfiles/nginx/copy/etc/nginx /etc \
    && mv /tmp/nginx.conf.d /etc/nginx/conf.d \
    && rm -rf /tmp/docker && cd ~/ \
  <% end %>

  && mkdir -p /home/jekyll && \
  addgroup -Sg 1000 jekyll &&  \
  adduser  -SG jekyll -u 1000 -h /home/jekyll jekyll && \
  chown jekyll:jekyll /home/jekyll && \

  cd ~ && \
  yes | gem update --system --no-document -- --use-system-libraries && \
  yes | gem update --no-document -- --use-system-libraries && \

  repo=$(docker-helper git_clone_ruby_repo "<%= @metadata['version'].fallback %>") && \
  if [ ! -z "$repo" ]; \
  then \
    cd $repo && \
    rake build && gem install pkg/jekyll-*.gem --no-document -- \
      --use-system-libraries && \
    rm -rf $repo; \
  else \
    yes | docker-helper ruby_install_gem \
      "jekyll@<%= @metadata['version'].fallback %>" --no-document -- \
        --use-system-libraries; \
  fi && \

  cd ~ && \
  mkdir -p /usr/share/ruby && \
  <% unless (gems = @metadata["gems"].as_string_set).empty? %>
    echo "<%= gems %>" > /usr/share/ruby/default-gems && \
  <% end %>

  docker-helper install_default_gems && \
  apk del <%= @metadata["remove_pkgs"].as_string_set %> && \
  gem clean && gem install bundler --no-document && \

  mkdir -p /srv/jekyll && \
  chown jekyll:jekyll /srv/jekyll && \
  echo 'jekyll ALL=NOPASSWD:ALL' >> /etc/sudoers && \
  rm -rf /usr/lib/ruby/gems/*/cache/*.gem && \
  docker-helper cleanup
WORKDIR /srv/jekyll
EXPOSE 4000 80
