#!/usr/bin/env groovy
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec
import java.security.Key
import java.security.spec.KeySpec


String encrypt(String strToEncrypt, String encryptionKey) {

    //String encryptionKey = "1234567912345678" //Paste your key here
    Key aesKey = new SecretKeySpec(encryptionKey.getBytes("UTF-8"), "AES")
    if (!strToEncrypt) return strToEncrypt
    Cipher cipher = Cipher.getInstance("AES/ECB/PKCS5Padding")
    cipher.init(Cipher.ENCRYPT_MODE, aesKey)
    String encryptedStr = cipher.doFinal(strToEncrypt.getBytes("UTF-8")).encodeBase64()
    return encryptedStr
}

encrypt("my-secret-key", "1234567912345678")

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    tools {
          jdk 'openjdk11'
          maven 'maven 3.6.3'
          dockerTool 'docker-latest'
    }

    environment {
        SECRET_KEY = credentials('secret-key') //Retrieved from AKV
        POM_VERSION = getVersion()
        JAR_NAME = getJarName()
        AWS_ECR_REGION = 'us-west-2'
        AWS_ECS_SERVICE = 'ch-dev-user-api-service'
        AWS_ECS_TASK_DEFINITION = 'ch-dev-user-api-taskdefinition'
        AWS_ECS_COMPATIBILITY = 'FARGATE'
        AWS_ECS_NETWORK_MODE = 'awsvpc'
        AWS_ECS_CPU = '256'
        AWS_ECS_MEMORY = '512'
        AWS_ECS_CLUSTER = 'ecsakv'
        AWS_ECS_TASK_DEFINITION_PATH = './ecs/container-definition-update-image.json'
        AWS_ECS_TASK_DEFINITION_NEW_PATH = './11.json'
//         SECRET_NAME = "SECRET_FROM_AKV".bytes.encodeBase64().toString()
         SECRET_NAME = "SECRET_FROM_AKV"
     //   SECRET_VALUE = SECRET_KEY.bytes.encodeBase64().toString()
        // SECRET_VALUE = encrypt(SECRET_KEY, "1234567912345678") 
         SECRET_VALUE = encrypt("my-secret-key", "1234567912345678")
//         JSON_STRING = '{"\"bucketname"\":${SECRET_KEY}}' .bytes.encodeBase64().toString()
        JSON_STRING = '{"environment": [{ "name": ${SECRET_NAME},"value": ${SECRET_VALUE}}]}'
    }
    stages {
        stage('Build & Test') {
            steps {
                withMaven(options: [artifactsPublisher(), mavenLinkerPublisher(), dependenciesFingerprintPublisher(disabled: true), jacocoPublisher(disabled: true), junitPublisher(disabled: true)]) {
                    sh "mvn -B -U clean package"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                withCredentials([string(credentialsId: 'AWS_REPOSITORY_URL_SECRET', variable: 'AWS_ECR_URL')]) {
                    script {
                        docker.build("${AWS_ECR_URL}:${POM_VERSION}", "--build-arg JAR_FILE=${JAR_NAME} --build-arg AKV_SECRET_NAME=${SECRET_NAME} --build-arg AKV_SECRET_VALUE=${SECRET_KEY} .")
                    }
                }
            }
        }

        stage('Push image to ECR') {
            steps {
                withCredentials([string(credentialsId: 'AWS_REPOSITORY_URL_SECRET', variable: 'AWS_ECR_URL')]) {
                    withAWS(region: "${AWS_ECR_REGION}", credentials: 'personal-aws-ecr') {
                        script {
                            def login = ecrLogin()
                            sh('#!/bin/sh -e\n' + "${login}") // hide logging
                            docker.image("${AWS_ECR_URL}:${POM_VERSION}").push()
                        }
                    }
                }
            }
        }

        stage('Deploy in ECS') {
            steps {
                withCredentials([string(credentialsId: 'AWS_EXECUTION_ROL_SECRET', variable: 'AWS_ECS_EXECUTION_ROL'),string(credentialsId: 'AWS_REPOSITORY_URL_SECRET', variable: 'AWS_ECR_URL')]) {
                    script {
                        updateContainerDefinitionJsonWithImageVersion()
                        sh ("touch 3.json")
                        sh ("echo $JSON_STRING > ./3.json | cat ./3.json")
                        sh ("sh ./convertjson.sh")
//                         sh ("cat ./ecs/container-definition-update-image.json | sed '1d; $d'  > 9.json")
                        sh ("cat ./9.json")                        
                        sh ("pwd")


                        ////////sh ("$JSON_STRING = '{bucketname:${SECRET_KEY}}' | echo $JSON_STRING > 3.json | cat 3.json")
                    //    sh("/snap/bin/aws ecs register-task-definition --region ${AWS_ECR_REGION} --family ${AWS_ECS_TASK_DEFINITION} --execution-role-arn ${AWS_ECS_EXECUTION_ROL} --requires-compatibilities ${AWS_ECS_COMPATIBILITY} --network-mode ${AWS_ECS_NETWORK_MODE} --cpu ${AWS_ECS_CPU} --memory ${AWS_ECS_MEMORY} --container-definitions file://${AWS_ECS_TASK_DEFINITION_PATH}")
                        sh("/snap/bin/aws ecs register-task-definition --region ${AWS_ECR_REGION} --family ${AWS_ECS_TASK_DEFINITION} --execution-role-arn ${AWS_ECS_EXECUTION_ROL} --requires-compatibilities ${AWS_ECS_COMPATIBILITY} --network-mode ${AWS_ECS_NETWORK_MODE} --cpu ${AWS_ECS_CPU} --memory ${AWS_ECS_MEMORY} --container-definitions file://${AWS_ECS_TASK_DEFINITION_NEW_PATH}")
                        def taskRevision = sh(script: "/snap/bin/aws ecs describe-task-definition --task-definition ${AWS_ECS_TASK_DEFINITION} | egrep \"revision\" | tr \"/\" \" \" | awk '{print \$2}' | sed 's/\"\$//'", returnStdout: true)
                       sh("/snap/bin/aws ecs update-service --cluster ${AWS_ECS_CLUSTER} --service ${AWS_ECS_SERVICE} --task-definition ${AWS_ECS_TASK_DEFINITION}")
                        ////////sh("/usr/local/bin/aws ecs update-service --overrides '{ "containerOverrides": [ { "name": "CONTAINER_NAME_FROM_TASK", "environment": [ { "name": "SECRET_KEY", "value": ${SECRET_KEY} }] } ] }' --cluster ${AWS_ECS_CLUSTER} --service ${AWS_ECS_SERVICE} --task-definition ${AWS_ECS_TASK_DEFINITION}:${taskRevision}")

                    } 

                }
            }
        }
    }

//     post {
//         always {
//             withCredentials([string(credentialsId: 'AWS_REPOSITORY_URL_SECRET', variable: 'AWS_ECR_URL')]) {
//                 junit allowEmptyResults: true, testResults: 'target/surfire-reports/*.xml'
//                 publishHTML([allowMissing: true, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'target/site/jacoco-ut/', reportFiles: 'index.html', reportName: 'Unit Testing Coverage', reportTitles: 'Unit Testing Coverage'])
//                 jacoco(execPattern: 'target/jacoco-ut.exec')
//                 deleteDir()
//                 sh "docker rmi ${AWS_ECR_URL}:${POM_VERSION}"
//             }
//         }
//     }
}

def getJarName() {
    def jarName = getName() + '-' + getVersion() + '.jar'
    echo "jarName: ${jarName}"
    return  jarName
}

def getVersion() {
    def pom = readMavenPom file: './pom.xml'
    return pom.version
}

def getName() {
    def pom = readMavenPom file: './pom.xml'
    return pom.name
}

def updateContainerDefinitionJsonWithImageVersion() {
    def containerDefinitionJson = readJSON file: AWS_ECS_TASK_DEFINITION_PATH, returnPojo: true
    containerDefinitionJson[0]['image'] = "${AWS_ECR_URL}:${POM_VERSION}".inspect()
    echo "task definiton json: ${containerDefinitionJson}"
    writeJSON file: AWS_ECS_TASK_DEFINITION_PATH, json: containerDefinitionJson
}
