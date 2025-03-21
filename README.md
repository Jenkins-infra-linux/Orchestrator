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
## MySQL 마스터-슬레이브 레플리케이션 설정 및 동기화 완료

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
