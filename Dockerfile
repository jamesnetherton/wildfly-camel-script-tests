FROM jamesnetherton/groovy

RUN apk --update add bash ruby ruby-json && \
    gem install jgrep --no-ri --no-rdoc

ADD . /wildfly-camel-script-tests

ENTRYPOINT [ "/bin/sh", "/wildfly-camel-script-tests/run-tests.sh" ]
