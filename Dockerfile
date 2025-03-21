# 1단계: JDK 포함된 이미지를 기반으로 애플리케이션 환경을 설정
FROM eclipse-temurin:17-jre-alpine

# 현재 디렉토리에서 JAR 파일을 컨테이너의 /app 디렉토리로 복사
COPY sh.jar /app/sh.jar

# 컨테이너 실행 시 JAR 파일을 실행
CMD ["java", "-jar", "/app/sh.jar"]
