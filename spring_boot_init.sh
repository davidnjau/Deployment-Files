#!/bin/bash

# Usage: ./spring_boot_init.sh service_name1 service_name2 service_name3 common
# First argument is root project name, others are module names

ROOT_PROJECT=$1
shift
MODULES=("$@")

if [ -z "$ROOT_PROJECT" ] || [ "${#MODULES[@]}" -eq 0 ]; then
  echo "Usage: $0 <root-project-name> <module1> <module2> ..."
  exit 1
fi

echo "Creating root project: $ROOT_PROJECT"
mkdir "$ROOT_PROJECT" && cd "$ROOT_PROJECT"

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
</project>
EOF

# Loop to create each module
for MODULE in "${MODULES[@]}"; do
  echo "Creating module: $MODULE"
  mkdir -p "$MODULE/src/main/java/com/${ROOT_PROJECT//-//}/$MODULE"
  mkdir -p "$MODULE/src/main/resources"
  mkdir -p "$MODULE/src/test/java"

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
  </dependencies>
</project>
EOF

  # Add minimal main class
  MAIN_CLASS_NAME="$(echo "$MODULE" | sed -E 's/-//g' | sed -E 's/(^|_)([a-z])/\U\2/g')Application"
  PACKAGE_NAME="com.${ROOT_PROJECT//-/.}.${MODULE//-/.}"
  MAIN_DIR="$MODULE/src/main/java/$(echo $PACKAGE_NAME | tr . /)"

  mkdir -p "$MAIN_DIR"
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

done

echo "✅ Project structure generated successfully in ./$ROOT_PROJECT"
