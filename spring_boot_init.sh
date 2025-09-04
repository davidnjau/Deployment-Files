#!/bin/bash

# ===============================================================
# Spring Boot Multi-Module Project Creator / Updater
# ===============================================================

create_new_project() {
  read -p "Enter root project name: " ROOT_PROJECT
  read -p "Enter service module names (space separated, exclude 'common'): " -a USER_MODULES

  # Always include common
  MODULES=("common" "${USER_MODULES[@]}")

  echo "Creating root project: $ROOT_PROJECT"
  mkdir "$ROOT_PROJECT" && cd "$ROOT_PROJECT" || exit 1

  # Create parent pom.xml
  cat > pom.xml <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.${ROOT_PROJECT}</groupId>
  <artifactId>${ROOT_PROJECT}</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>
  <modules>
$(for m in "${MODULES[@]}"; do echo "    <module>$m</module>"; done)
  </modules>

  <dependencyManagement>
    <dependencies>
      <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-dependencies</artifactId>
        <version>3.2.2</version>
        <type>pom</type>
        <scope>import</scope>
      </dependency>
    </dependencies>
  </dependencyManagement>

  <build>
    <pluginManagement>
      <plugins>
        <plugin>
          <groupId>org.springframework.boot</groupId>
          <artifactId>spring-boot-maven-plugin</artifactId>
        </plugin>
        <plugin>
          <groupId>org.jetbrains.kotlin</groupId>
          <artifactId>kotlin-maven-plugin</artifactId>
          <version>1.9.23</version>
          <executions>
            <execution>
              <id>compile</id>
              <phase>compile</phase>
              <goals>
                <goal>compile</goal>
              </goals>
            </execution>
            <execution>
              <id>test-compile</id>
              <phase>test-compile</phase>
              <goals>
                <goal>test-compile</goal>
              </goals>
            </execution>
          </executions>
          <configuration>
            <jvmTarget>17</jvmTarget>
          </configuration>
        </plugin>
      </plugins>
    </pluginManagement>
  </build>

</project>
EOF

  create_modules "$ROOT_PROJECT" "${MODULES[@]}"
  echo "✅ New project $ROOT_PROJECT created successfully."
}

update_existing_project() {
  if [ ! -f "pom.xml" ]; then
    echo "❌ No pom.xml found in current directory. Run inside the root project."
    exit 1
  fi

  if ! grep -q "<packaging>pom</packaging>" pom.xml; then
    echo "❌ Current project is not a multi-module Maven project."
    exit 1
  fi

  echo "✅ Valid multi-module project detected."
  read -p "Enter new module names to add (space separated): " -a NEW_MODULES

  ROOT_PROJECT=$(xmllint --xpath "/*[local-name()='project']/*[local-name()='artifactId']/text()" pom.xml 2>/dev/null)
  if [ -z "$ROOT_PROJECT" ]; then
    echo "❌ Could not determine root project name from pom.xml"
    exit 1
  fi

  for MODULE in "${NEW_MODULES[@]}"; do
    echo "Adding module: $MODULE"

    # Add <module> entry if not present
    if ! grep -q "<module>$MODULE</module>" pom.xml; then
      sed -i "/<modules>/a \    <module>$MODULE</module>" pom.xml
    fi

    # Create the module structure if not exists
    if [ ! -d "$MODULE" ]; then
      mkdir -p "$MODULE/src/main/java/com/${ROOT_PROJECT//-//}/$MODULE"
      mkdir -p "$MODULE/src/main/kotlin/com/${ROOT_PROJECT//-//}/$MODULE"
      mkdir -p "$MODULE/src/main/resources"
      mkdir -p "$MODULE/src/test/java"
      mkdir -p "$MODULE/src/test/kotlin"

      create_module_pom "$ROOT_PROJECT" "$MODULE"
      create_entrypoint_and_yml "$ROOT_PROJECT" "$MODULE"
    fi
  done

  echo "✅ Existing project updated with new modules: ${NEW_MODULES[*]}"
}

create_modules() {
  ROOT_PROJECT=$1
  shift
  MODULES=("$@")

  for MODULE in "${MODULES[@]}"; do
    echo "Creating module: $MODULE"

    mkdir -p "$MODULE/src/main/java/com/${ROOT_PROJECT//-//}/$MODULE"
    mkdir -p "$MODULE/src/main/kotlin/com/${ROOT_PROJECT//-//}/$MODULE"
    mkdir -p "$MODULE/src/main/resources"
    mkdir -p "$MODULE/src/test/java"
    mkdir -p "$MODULE/src/test/kotlin"

    create_module_pom "$ROOT_PROJECT" "$MODULE"
    create_entrypoint_and_yml "$ROOT_PROJECT" "$MODULE"
  done
}

create_module_pom() {
  ROOT_PROJECT=$1
  MODULE=$2

  cat > "$MODULE/pom.xml" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <parent>
    <groupId>com.${ROOT_PROJECT}</groupId>
    <artifactId>${ROOT_PROJECT}</artifactId>
    <version>1.0.0</version>
  </parent>
  <artifactId>$MODULE</artifactId>

  <dependencies>
    <dependency>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter</artifactId>
    </dependency>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-stdlib</artifactId>
    </dependency>
    <dependency>
      <groupId>org.jetbrains.kotlin</groupId>
      <artifactId>kotlin-reflect</artifactId>
    </dependency>
  </dependencies>
</project>
EOF
}

create_entrypoint_and_yml() {
  ROOT_PROJECT=$1
  MODULE=$2

  # Skip dependency-only modules
  if [[ "$MODULE" == "common" || "$MODULE" == "shared" || "$MODULE" == "lib" ]]; then
    return
  fi

  MAIN_CLASS_NAME="$(echo "$MODULE" | sed -E 's/-//g' | sed -E 's/(^|_)([a-z])/\U\2/g')Application"
  PACKAGE_NAME="com.${ROOT_PROJECT//-/.}.${MODULE//-/.}"
  MAIN_DIR="$MODULE/src/main/java/$(echo $PACKAGE_NAME | tr . /)"
  mkdir -p "$MAIN_DIR"

  # Generate Spring Boot entry point
  cat > "$MAIN_DIR/$MAIN_CLASS_NAME.java" <<EOF
package $PACKAGE_NAME;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class $MAIN_CLASS_NAME {
    public static void main(String[] args) {
        SpringApplication.run($MAIN_CLASS_NAME.class, args);
    }
}
EOF

  # Generate default application.yml
  cat > "$MODULE/src/main/resources/application.yml" <<EOF
server:
  port: 8080

spring:
  application:
    name: $MODULE
  datasource:
    url: jdbc:postgresql://localhost:5432/${MODULE}_db
    username: ${MODULE}_user
    password: changeme
    driver-class-name: org.postgresql.Driver

logging:
  level:
    root: INFO
    org:
      springframework:
        security:
          web:
            FilterChainProxy: DEBUG      # Logs which SecurityFilterChain matches
          authorization: DEBUG           # Logs authorization decisions
          authentication: DEBUG          # Logs authentication details
        web:
          servlet:
            DispatcherServlet: DEBUG      # Logs request handling
            mvc:
              method:
                annotation: DEBUG         # Logs which @RequestMapping method is chosen
      keycloak: DEBUG
EOF
}

# ===============================================================
# Entry point
# ===============================================================
echo "Do you want to (1) Create a new project or (2) Update an existing project?"
read -p "Enter 1 or 2: " CHOICE

if [ "$CHOICE" -eq 1 ]; then
  create_new_project
elif [ "$CHOICE" -eq 2 ]; then
  update_existing_project
else
  echo "Invalid option. Exiting."
  exit 1
fi
