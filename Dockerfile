FROM dingxizheng/ffmpeg-ruby-2.7 

RUN rm -rf /var/app
WORKDIR /var/app

# Copy the main application.
ADD . ./
RUN bundle install

# Disable ruby warnings
ENV RUBYOPT='-W0'

CMD bin/app