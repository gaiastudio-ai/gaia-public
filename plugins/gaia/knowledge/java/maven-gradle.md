---
name: Maven and Gradle Build Patterns
stack: java
version: "1.0"
focus: [build-tools]
---

# Maven and Gradle Build Patterns

## Principle

Use multi-module builds to organize large projects with shared dependencies managed through a BOM (Bill of Materials) or parent POM. Keep build scripts declarative, version-lock all dependencies, and use plugins for code generation, testing, and packaging. Choose Maven for convention-heavy projects and Gradle for performance-critical or highly customized builds.

## Rationale

Build tool consistency prevents "works on my machine" issues. A parent POM or BOM centralizes dependency versions so all modules use the same library versions, eliminating conflicts. Multi-module builds enable code reuse (shared DTOs, utilities) while maintaining independent compilation. Plugin management ensures consistent code quality (Checkstyle, SpotBugs) and packaging (Spring Boot fat JARs, Docker images).

## Pattern Examples

### Pattern 1: Maven Multi-Module with BOM

```xml
<!-- parent pom.xml -->
<project>
    <groupId>com.example</groupId>
    <artifactId>platform-parent</artifactId>
    <version>1.0.0</version>
    <packaging>pom</packaging>

    <modules>
        <module>common</module>
        <module>user-service</module>
        <module>order-service</module>
    </modules>

    <properties>
        <java.version>21</java.version>
        <spring-boot.version>3.3.0</spring-boot.version>
        <mapstruct.version>1.5.5.Final</mapstruct.version>
    </properties>

    <dependencyManagement>
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-dependencies</artifactId>
                <version>${spring-boot.version}</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
            <dependency>
                <groupId>com.example</groupId>
                <artifactId>common</artifactId>
                <version>${project.version}</version>
            </dependency>
        </dependencies>
    </dependencyManagement>
</project>

<!-- user-service/pom.xml -->
<project>
    <parent>
        <groupId>com.example</groupId>
        <artifactId>platform-parent</artifactId>
        <version>1.0.0</version>
    </parent>
    <artifactId>user-service</artifactId>

    <dependencies>
        <dependency>
            <groupId>com.example</groupId>
            <artifactId>common</artifactId>
            <!-- version inherited from parent -->
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
```

### Pattern 2: Gradle Kotlin DSL with Version Catalog

```kotlin
// gradle/libs.versions.toml — centralized version catalog
// [versions]
// spring-boot = "3.3.0"
// mapstruct = "1.5.5.Final"
// [libraries]
// spring-boot-web = { module = "org.springframework.boot:spring-boot-starter-web" }
// spring-boot-test = { module = "org.springframework.boot:spring-boot-starter-test" }
// mapstruct = { module = "org.mapstruct:mapstruct", version.ref = "mapstruct" }

// build.gradle.kts (root)
plugins {
    java
    id("org.springframework.boot") version libs.versions.spring.boot apply false
}

subprojects {
    apply(plugin = "java")

    java {
        sourceCompatibility = JavaVersion.VERSION_21
    }

    repositories {
        mavenCentral()
    }

    tasks.withType<Test> {
        useJUnitPlatform()
    }
}

// user-service/build.gradle.kts
plugins {
    id("org.springframework.boot")
}

dependencies {
    implementation(project(":common"))
    implementation(libs.spring.boot.web)
    implementation(libs.mapstruct)
    testImplementation(libs.spring.boot.test)
}
```

### Pattern 3: Plugin Configuration for Quality

```xml
<!-- Maven plugin management in parent POM -->
<build>
    <pluginManagement>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.12.1</version>
                <configuration>
                    <release>${java.version}</release>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>${mapstruct.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                            <version>${lombok.version}</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.11</version>
                <executions>
                    <execution>
                        <goals><goal>prepare-agent</goal></goals>
                    </execution>
                    <execution>
                        <id>report</id>
                        <phase>verify</phase>
                        <goals><goal>report</goal></goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </pluginManagement>
</build>
```

## Anti-Patterns

- **Unmanaged dependency versions**: Declaring versions in each module instead of the parent/BOM. Leads to version conflicts.
- **Fat parent POM with all dependencies**: Declaring dependencies (not just `dependencyManagement`) in the parent forces all modules to inherit them.
- **Skipping tests in CI**: `mvn install -DskipTests` hides regressions. Only skip in local exploratory builds.
- **Build logic in scripts outside the build tool**: Wrapping Maven/Gradle in shell scripts that duplicate what plugins provide.

## Integration Points

- **Spring Boot**: Spring Boot Maven/Gradle plugin handles fat JAR packaging and dev-tools; see `spring-boot-patterns.md`.
- **JPA**: Annotation processing (Hibernate metamodel, MapStruct) configured in compiler plugin; see `jpa-patterns.md`.
- **Microservices**: Multi-module layout maps to service boundaries; see `microservices.md`.
- **CI/CD**: Build tool commands (`mvn verify`, `gradle build`) are the CI pipeline entry point.
