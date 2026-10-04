#!/usr/bin/env bash
# shellcheck disable=SC2016  # JMESPathi päringutes on backtick-id, mitte kesta asendused
# Otsib AWS-i kontolt ressursse, mis kulutavad krediiti ka siis, kui sa neid enam ei kasuta.
# Käivita iga pilve kodutöö lõpus (control node'il või AWS CloudShellis).
#
# Kasutus:
#   bash aws-leftovers.sh                      # regioonid eu-north-1 ja us-east-1
#   bash aws-leftovers.sh -r "eu-north-1 eu-central-1"
#   bash aws-leftovers.sh --all-regions        # kõik konto jaoks lubatud regioonid (aeglane)
#   AWS_PROFILE=labseis bash aws-leftovers.sh
#
# Väljumiskood: 0 = tasulisi jääke pole, 1 = leiti midagi (vt "KULU" read), 2 = mõni päring kukkus
# (õigused või võrk), seega tulemus pole usaldusväärne.
# "INFO" read on odavad või tasuta asjad (ECR repo, S3 bucket, tühi VPC). Need ei mõjuta väljumiskoodi.
set -uo pipefail

REGIONS="eu-north-1 us-east-1"
ALL=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--regions) REGIONS="${2:?regioonide nimekiri puudub}"; shift 2 ;;
        --all-regions) ALL=1; shift ;;
        -h|--help) sed -n "3,16p" "$0"; exit 0 ;;
        *) echo "Tundmatu argument: $1" >&2; exit 2 ;;
    esac
done

command -v aws > /dev/null || { echo "aws CLI puudub (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)" >&2; exit 2; }

if ! who=$(aws sts get-caller-identity --query Arn --output text 2> /dev/null); then
    echo "AWS-i sisselogimine puudub: aws login (või aws configure) ja proovi uuesti" >&2
    exit 2
fi
echo "Konto: $who"
if [[ "$who" == *":root" ]]; then
    echo "HOIATUS: töötad root-kasutajana. Kasuta IAM kasutajat (vt kodutood.md)." >&2
fi

if [[ $ALL -eq 1 ]]; then
    REGIONS=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text) || exit 2
fi

found=0
errors=0

# kontroll <KULU|INFO> <region> <kirjeldus> <aws argumendid...>
# aws käsk peab andma tekstiväljundi, üks ressurss real; tühi väljund = korras.
kontroll() {
    local kind="$1" region="$2" what="$3"
    shift 3
    local out
    if ! out=$(aws --region "$region" "$@" --output text 2>&1); then
        # teenus pole regioonis saadaval → pole ka ressursse
        if grep -qiE 'Could not connect|not supported|UnrecognizedClient|is not available|UnknownEndpoint' <<< "$out"; then
            return 0
        fi
        echo "  VIGA   $what: $(head -1 <<< "$out")"
        errors=$((errors + 1))
        return 0
    fi
    out=$(grep -vE '^(None)?[[:space:]]*$' <<< "$out" || true)
    [[ -z "$out" ]] && return 0
    while IFS= read -r line; do
        printf '  %-6s %-28s %s\n' "$kind" "$what" "$line"
    done <<< "$out"
    [[ "$kind" == KULU ]] && found=$((found + 1))
    return 0
}

for r in $REGIONS; do
    echo "== $r"
    kontroll KULU "$r" "EC2 instants" ec2 describe-instances \
        --filters Name=instance-state-name,Values=pending,running,stopping,stopped \
        --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,Tags[?Key==`Name`]|[0].Value]'
    kontroll KULU "$r" "EBS ketas (vaba)" ec2 describe-volumes \
        --filters Name=status,Values=available --query 'Volumes[].[VolumeId,Size,VolumeType]'
    kontroll KULU "$r" "Elastic IP" ec2 describe-addresses \
        --query 'Addresses[].[PublicIp,AllocationId,InstanceId]'
    kontroll KULU "$r" "NAT gateway" ec2 describe-nat-gateways \
        --filter Name=state,Values=pending,available --query 'NatGateways[].[NatGatewayId,VpcId,State]'
    kontroll KULU "$r" "VPC endpoint (interface)" ec2 describe-vpc-endpoints \
        --filters Name=vpc-endpoint-type,Values=Interface --query 'VpcEndpoints[].[VpcEndpointId,ServiceName]'
    kontroll KULU "$r" "Load balancer (ALB/NLB)" elbv2 describe-load-balancers \
        --query 'LoadBalancers[].[LoadBalancerName,Type,State.Code]'
    kontroll KULU "$r" "Classic ELB" elb describe-load-balancers \
        --query 'LoadBalancerDescriptions[].[LoadBalancerName]'
    kontroll KULU "$r" "RDS instants" rds describe-db-instances \
        --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceClass,DBInstanceStatus]'
    kontroll KULU "$r" "RDS klaster" rds describe-db-clusters \
        --query 'DBClusters[].[DBClusterIdentifier,Engine,Status]'
    kontroll KULU "$r" "ElastiCache" elasticache describe-cache-clusters \
        --query 'CacheClusters[].[CacheClusterId,CacheNodeType,CacheClusterStatus]'
    kontroll KULU "$r" "ElastiCache serverless" elasticache describe-serverless-caches \
        --query 'ServerlessCaches[].[ServerlessCacheName,Status]'
    kontroll KULU "$r" "Amazon MQ broker" mq list-brokers \
        --query 'BrokerSummaries[].[BrokerName,HostInstanceType,BrokerState]'
    kontroll KULU "$r" "EKS klaster" eks list-clusters --query 'clusters[]'
    kontroll KULU "$r" "Elastic Beanstalk" elasticbeanstalk describe-environments \
        --query 'Environments[?Status!=`Terminated`].[EnvironmentName,Status]'

    # ECS: tühi klaster on tasuta, töötav teenus (Fargate task) mitte
    if clusters=$(aws --region "$r" ecs list-clusters --query 'clusterArns[]' --output text 2> /dev/null); then
        for c in $clusters; do
            [[ "$c" == None ]] && continue
            kontroll KULU "$r" "ECS teenus (${c##*/})" ecs list-services --cluster "$c" --query 'serviceArns[]'
            kontroll INFO "$r" "ECS klaster" ecs describe-clusters --clusters "$c" \
                --query 'clusters[].[clusterName,status]'
        done
    fi

    kontroll INFO "$r" "EBS snapshot (oma)" ec2 describe-snapshots --owner-ids self \
        --query 'Snapshots[].[SnapshotId,VolumeSize,StartTime]'
    kontroll INFO "$r" "ECR repo" ecr describe-repositories --query 'repositories[].[repositoryName]'
    kontroll INFO "$r" "VPC (mitte vaike)" ec2 describe-vpcs --filters Name=is-default,Values=false \
        --query 'Vpcs[].[VpcId,CidrBlock,Tags[?Key==`Name`]|[0].Value]'
done

echo "== globaalne"
kontroll INFO us-east-1 "S3 bucket" s3api list-buckets --query 'Buckets[].[Name]'
# Pikaajalised võtmed (K5/K6 kodutöö). Rolli või SSO-ga sisse logides seda päringut ei saa teha, siis jäetakse vahele.
if keys=$(aws iam list-access-keys --query 'AccessKeyMetadata[].[AccessKeyId,Status,CreateDate]' --output text 2> /dev/null); then
    while IFS= read -r line; do
        [[ -n "$line" ]] && printf '  %-6s %-28s %s\n' INFO "IAM access key (sinu)" "$line"
    done <<< "$keys"
fi

echo
if [[ $errors -gt 0 ]]; then
    echo "TULEMUS: $errors päringut kukkus, kontroll pole täielik (õigused? võrk?)"
    exit 2
fi
if [[ $found -gt 0 ]]; then
    echo "TULEMUS: leiti $found tasulist ressursitüüpi. Kustuta need ja käivita skript uuesti."
    exit 1
fi
echo "TULEMUS: tasulisi jääke pole (regioonid: $(echo "$REGIONS" | tr '\n' ' '))"
exit 0
