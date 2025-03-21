# Orchestrator
## 🤝 Team Members
| <img src="https://github.com/kcklkb.png" width="200px"> | <img src="https://github.com/woody6624.png" width="200px"> | <img src="https://github.com/parkjhhh.png" width="200px"> | <img src="https://github.com/unoYoon.png" width="200px"> |
| :---: | :---: | :---: | :---: |
| [김창규](https://github.com/kcklkb) | [김우현](https://github.com/woody6624) | [박지혜](https://github.com/parkjhhh) | [윤원호](https://github.com/unoYoon) |

---
### 📊프로젝트 소개

**Docker Compose** 및 **스크립트**를 활용하여 컨테이너를 손쉽게 관리하고 시스템 장애 시 빠르게 복구할 수 있는 환경을 제공하고자 했습니다. 또한, 서비스 및 데이터의 **고가용성**을 확보하기 위해 MySQL DB **이중화** 및 데이터 **백업 자동화**를 구현했습니다. 두 개의 MySQL DB 컨테이너를 생성하여 데이터의 가용성을 높이고, **볼륨 마운트**를 통해 **데이터 지속성**을 보장합니다.

---
### 🎯프로젝트 목표

1. **서비스 자동화**:
    - `docker-compose down`과 `docker-compose up`을 통해 자동으로 컨테이너를 관리하고 재시작.
2. **MySQL 이중화 및 고가용성 보장**
    - 두 개의 MySQL 컨테이너를 운영하여 하나의 컨테이너가 장애 시 다른 컨테이너가 서비스를 지속하도록 설정.
3. **데이터 백업 및 지속성 확보:**
    - Docker 볼륨을 사용하여 데이터 지속성을 보장하고 외부에 데이터 백업을 자동화
  
---
### 💻개발환경

<img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" /> <img src="https://img.shields.io/badge/VMware-607078?style=for-the-badge&logo=vmware&logoColor=white" alt="VMware" /> <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu" /> <img src="https://img.shields.io/badge/JDK-007396?style=for-the-badge&logo=openjdk&logoColor=white" alt="JDK" />


---
## 방법 1. MySQL 마스터-슬레이브 레플리케이션 설정 및 동기화 완료

### docker-compose.yml

```bash
ubuntu@ubuntu:~/JPA-docker$ cat docker-compose.yml
services:
  # MySQL Master 서버
  mysql-master:
    image: mysql:8.0
    container_name: mysql-8
    command: --server-id=1 --log-bin=mysql-bin --binlog-format=row
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: fisa
      MYSQL_USER: user01
      MYSQL_PASSWORD: user01
    ports:
      - "3306:3306"
    volumes:
      - mysql-master-data:/var/lib/mysql # 데이터 저장을 위한 볼륨
    networks:
      - spring-mysql-net

  # MySQL Slave 서버
  mysql-slave:
    image: mysql:8.0
    container_name: mysql-slave
    depends_on:
      - mysql-master
    command: --server-id=2 --log-bin=mysql-bin --binlog-format=row
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: fisa
      MYSQL_USER: user01
      MYSQL_PASSWORD: user01
    ports:
      - "3307:3306"
    volumes:
      - mysql-slave-data:/var/lib/mysql # 데이터 저장을 위한 볼륨
    networks:
      - spring-mysql-net

  # 스프링 부트 어플리케이션
  app:
    container_name: springbootapp
    build:
      context: .
      dockerfile: ./Dockerfile
    ports:
      - "8079:8079"
    environment:
      MYSQL_HOST: mysql-master  
      MYSQL_PORT: 3306
      MYSQL_DATABASE: fisa 
      MYSQL_USER: user01
      MYSQL_PASSWORD: user01
    depends_on:
      - mysql-master  
    networks:
      - spring-mysql-net

networks:
  spring-mysql-net:
    driver: bridge

volumes:
  mysql-master-data:
  mysql-slave-data:
```

### 마스터 db

#### **마스터 서버 설정**

- MySQL 마스터 서버에 로그인하고 레플리케이션 권한을 가진 사용자 (`user01`)를 생성하고 권한을 부여합니다.
- `SHOW MASTER STATUS;` 명령어로 **Binlog 파일** 이름과 **Position** 값을 확인합니다.

#### 마스터 db에 접속

```bash
docker exec -it mysql-8 mysql -u root -p
```

#### 마스터db에 유저와 레플리케이션 권한 설정

```bash
ALTER USER 'user01'@'%' IDENTIFIED WITH 'mysql_native_password' BY 'user01';

GRANT REPLICATION SLAVE ON *.* TO 'user01'@'%';

FLUSH PRIVILEGES;
```

#### 마스터 DB 상태 확인

```bash
mysql> SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000004 |     8074 |              |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
```

### 슬레이브 DB
⚠️ 슬레이브 DB의 구조는 마스터 DB의 구조와 동일해야 합니다.
#### **슬레이브 서버 설정**

- 슬레이브 서버에서 `CHANGE MASTER TO` 명령어를 사용하여 마스터 서버와 연결을 설정합니다.
- `START SLAVE;` 명령어로 레플리케이션을 시작합니다.

```bash
CHANGE MASTER TO
  MASTER_HOST='mysql-master', # docker-compose에 설정한 마스터DB의 서비스 명(호스트 명)
  MASTER_USER='user01',
  MASTER_PASSWORD='user01',
  MASTER_LOG_FILE='mysql-bin.000004', # SHOW MASTER STATUS에서 나오는 file 값
  MASTER_LOG_POS=8074; # SHOW MASTER STATUS에서 나오는 Position 값

mysql> START SLAVE; # 레플리케이션 시작
```

#### **레플리케이션 상태 확인**

- `SHOW SLAVE STATUS\G` 명령어로 슬레이브 서버의 상태를 확인합니다.
- `Slave_IO_Running`과 `Slave_SQL_Running`이 `YES`로 표시되면, 레플리케이션이 정상적으로 작동하고 있다는 뜻입니다.

```sql
mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: mysql-master
                  Master_User: user01
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000004
          Read_Master_Log_Pos: 8074
               Relay_Log_File: 40ac1dda8d39-relay-bin.000002
                Relay_Log_Pos: 5146
        Relay_Master_Log_File: mysql-bin.000004
             Slave_IO_Running: Yes  ⚠️check!
            Slave_SQL_Running: Yes  ⚠️check!
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 8074
              Relay_Log_Space: 5363
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 1
                  Master_UUID: 4bc25a7e-05fa-11f0-a474-3a37024b6791
             Master_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set:
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
       Master_public_key_path:
        Get_master_public_key: 0
            Network_Namespace:

```
### 실행 결과
![Image](https://github.com/user-attachments/assets/aef99b48-29c4-4fb9-a449-1e7105038911)
<br>
<br>

## 방법 2.  MySQL 자동 백업 컨테이너 (로컬 Dump 저장)

<br>

### 1단계 - 실행 스크립트: `run.sh`

**목표:** `docker-compose.yml`, `Dockerfile`, 애플리케이션 파일을 기반으로 한 실행 스크립트를 만들어서 불필요한 리소스를 정리하고 컨테이너를 실행합니다.

```jsx
#!/bin/bash

# 사용하지 않는 컨테이너, 이미지, 네트워크, 볼륨 모두 정리
docker image prune -f     # 사용되지 않는 이미지 삭제
docker container prune -f # 중지된 컨테이너 삭제

# 컨테이너 실행
docker-compose up -d      # docker-compose로 컨테이너 백그라운드 실행
```

<br>


### 스크립트 설명:

1. **`docker image prune -f`**: 사용되지 않는 **Docker 이미지**를 삭제하여 디스크 공간을 확보합니다.
2. **`docker container prune -f`**: **중지된 Docker 컨테이너**를 삭제하여 불필요한 리소스를 정리합니다.
3. **`docker-compose up -d`**: `docker-compose.yml` 파일을 기반으로 **백그라운드에서 컨테이너를 실행**합니다.

<br>


### 사용 방법:

1. `run.sh` 파일을 생성한 후, 해당 파일에 실행 권한을 부여합니다.
    
    ```bash
    chmod +x run.sh
    ```
    
2. 스크립트를 실행합니다.
    
    ```bash
    ./run.sh
    ```
    

이 스크립트는 **컨테이너 실행 전에** **불필요한 리소스를 정리**하여, 

깔끔한 상태에서 새롭게 컨테이너를 실행할 수 있도록 돕습니다. 

`docker-compose.yml`과 `Dockerfile`을 준비한 후, 이 스크립트 하나로 

컨테이너와 이미지를 관리할 수 있습니다.

<br>


### **1. `docker-compose.yml` (MySQL + Spring Boot + 백업 설정)**

```yaml
docker-compose.yaml
복사편집
version: "1.0"

services:
  db:
    container_name: mysqldb
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: fisa
      MYSQL_USER: user01
      MYSQL_PASSWORD: user01
    networks:
      - spring-mysql-net
    healthcheck:
      test: ['CMD-SHELL', 'mysqladmin ping -h 127.0.0.1 -u root --password=$${MYSQL_ROOT_PASSWORD} || exit 1']
      interval: 10s
      timeout: 2s
      retries: 100
    volumes:
      - ./mysql_backup:/backup  # ✅ 로컬 디렉토리에 백업 저장

  app:
    container_name: springbootapp
    build:
      context: .
      dockerfile: ./Dockerfile
    ports:
      - "8080:8080"
    environment:
      MYSQL_HOST: db
      MYSQL_PORT: 3306
      MYSQL_DATABASE: fisa
      MYSQL_USER: user01
      MYSQL_PASSWORD: user01
    depends_on:
      db:
        condition: service_healthy
    networks:
      - spring-mysql-net

networks:
  spring-mysql-net:
    driver: bridge
```

---

<br>


### **2. `Dockerfile` (Spring Boot 앱 컨테이너 설정)**

<br>


```
Dockerfile

# Base Imge 설정
FROM openjdk:17-slim

# curl 설치 (slim 이미지에는 기본적으로 없음)
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /app

# 애플리케이션 JAR 파일 복사
COPY step06_SpringDataJPA-0.0.1-SNAPSHOT.jar app.jar

# 환경 변수 설정 (포트 변경이 용이하도록)
ENV SERVER_PORT=8080

# 헬스 체크 설정 (curl을 사용하여 애플리케이션이 정상 작동하는지 확인)
HEALTHCHECK --interval=10s --timeout=30s --retries=3 CMD curl -f http://localhost:${SERVER_PORT}/one || exit 1

# 애플리케이션 실행 (exec 방식 사용)
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

 ****

 <br>


### **3. `backup.sh` (MySQL 데이터베이스 백업 스크립트)**

<br>


```
#!/bin/bash

# 현재 날짜를 기준으로 백업 파일 이름 설정
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="./mysql_backup/db_backup_$TIMESTAMP.sql"

# MySQL 백업 실행
docker exec mysqldb mysqldump -u root -proot fisa > "$BACKUP_FILE"

# 오래된 백업 파일(7일 이상된 파일) 자동 삭제
find ./mysql_backup/ -type f -mtime +7 -exec rm {} \;
```

✅ `./mysql_backup/` 디렉토리에 **백업 파일 저장**

✅ **7일 이상된 백업 파일 자동 삭제**

---

<br>


### **4. `run.sh` (모든 컨테이너 실행 스크립트)**

<br>


```
#!/bin/bash

# 기존 컨테이너 정리
docker-compose down

# 컨테이너 실행
docker-compose up -d

# 백업 디렉토리 확인 및 생성
mkdir -p mysql_backup
```

✅ 실행하면 **기존 컨테이너를 종료하고 다시 시작**

✅ **백업 폴더(`mysql_backup/`)가 없으면 자동 생성**

---

<br>


### **5. 크론탭 설정 (1시간마다 자동 백업 실행)**

<br>


1. 크론탭 편집:
    
    ```
    crontab -e
    ```
    
2. 아래 내용 추가 (1시간마다 `backup.sh` 실행):
    
    ```
    0 * * * * /path/to/backup.sh
    ```
    

---

<br>


## **💡 실행 방법**

<br>


### **1️⃣ 프로젝트 실행**

<br>


```
chmod +x run.sh
./run.sh
```

<br>


### **2️⃣ 수동 백업 실행**

<br>


```
chmod +x backup.sh
./backup.sh
```

<br>


### **3️⃣ 자동 백업 활성화**

<br>


```
crontab -l  # 크론탭 확인
```

---

<br>


## **📌 정리**

<br>


✅ **MySQL 컨테이너 기반 데이터 백업**

✅ **`mysqldump`로 1시간마다 자동 백업**

✅ **7일 이상된 백업 파일 자동 삭제**

✅ **Spring Boot & MySQL 컨테이너와 함께 동작**

<br>


![mysql_backup 파일에 cron으로 설정된 시간에 잘 들어왔음을 확인할 수 있었습니다.](attachment:da5b948e-7c6b-418e-a20b-6186c58c723e:image.png)

mysql_backup 파일에 cron으로 설정된 시간에 잘 들어왔음을 확인할 수 있었습니다.

<br>


```jsx
-- MySQL dump 10.13  Distrib 8.0.41, for Linux (x86_64)
--
-- Host: localhost    Database: fisa
-- ------------------------------------------------------
-- Server version	8.0.41

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `people`
--

DROP TABLE IF EXISTS `people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `people` (
  `no` bigint NOT NULL,
  `age` int NOT NULL,
  `people_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `people`
--

LOCK TABLES `people` WRITE;
/*!40000 ALTER TABLE `people` DISABLE KEYS */;
/*!40000 ALTER TABLE `people` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `people_seq`
--

DROP TABLE IF EXISTS `people_seq`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `people_seq` (
  `next_val` bigint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `people_seq`
--

LOCK TABLES `people_seq` WRITE;
/*!40000 ALTER TABLE `people_seq` DISABLE KEYS */;
INSERT INTO `people_seq` VALUES (1);
/*!40000 ALTER TABLE `people_seq` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-03-21  2:14:28

```

<br>


### 백업 결과 확인 (Dump 파일 정보)

<br>


1. **데이터베이스 정보**:
   
    - 데이터베이스: `fisa`
      
    - MySQL 버전: 8.0.41
      
    - 문자셋: `utf8mb4`
      
2. **백업된 테이블**:
   
    - `people`: 이 테이블은 `no`, `age`, `people_name` 컬럼을 가지며, `no` 컬럼이 기본 키로 설정되어 있습니다.
      
    - `people_seq`: 이 테이블은 `next_val` 컬럼을 가지며, 값은 `1`로 설정되어 있습니다.
      
3. **백업 파일 생성 확인**:
   
    - 덤프 파일은 MySQL `mysqldump` 명령어로 생성된 SQL 스크립트 형식입니다.
      
    - 생성된 파일은 `fisa` 데이터베이스에 포함된 두 개의 테이블에 대한 구조와 데이터를 포함하고 있습니다.

<br>


### 다음 단계

<br>


1. **백업 파일 복원**:
   
    - 백업된 데이터를 MySQL에 복원하려면 다음 명령어를 사용합니다:
        
        ```bash
        mysql -u root -p fisa < /path/to/backup/file.sql
        ```
        

2. **백업 스크립트 점검**:
   
    - 스크립트가 주기적으로 실행되도록 설정한 크론탭은 정상적으로 작동한 것으로 보입니다. 백업 파일이 예상대로 생성되었음을 확인했으며, 이 파일을 사용해 복원 작업도 가능할 것입니다.
    
이로써 MySQL 데이터베이스의 주기적인 백업을 위한 작업이 정상적으로 진행되고 있음을 확인할 수 있습니다.
