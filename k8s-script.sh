#!/bin/bash

readonly COMPONENTS_RECORD="./components-record.txt"
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'

function init (){
  kubectl version > /dev/null 2>&1;

  if [ $? != 0 ]; then
    echo -e "${COLOR_RED}Sorry your kubectl comman cannot be used"
    exit 1
  fi

  local parameter=$1;

  if [ $parameter ]; then
    ENVIROMENT=$parameter;
  else
    echo -e "簡易啟動和刪除 k8s component 的 script, 會自動抓取同層目錄下名為 *-[dev | development | prod | production].yaml 腳本\n";
    echo -e "請輸入你要啟動的環境\n"
    echo -e "1. dev | development \n2. prod | production\n";

    read -p "請輸入: " ENVIROMENT;
  fi
}

init $1;

# 目的：希望用區域變數, 來取得被 created 的 k8s components record, 以減少全域變數
function get_components_record() {
  local components=();
  local is_creadted=$1;

  if [ -f $COMPONENTS_RECORD ]; then
    while IFS= read -r k8s_component;
      do
        if [ $is_creadted ]; then
          # 不需要被回傳, 用於顯示被 created 的 component
          echo -e "${COLOR_GREEN}$k8s_component created\n">&2;
        fi

        components+=($k8s_component)
      done < $COMPONENTS_RECORD
  fi

  # 這裡主要用於回傳，但同時也會被 echo to stdout(理想: 只是單傳 return 但不 echo)
  echo "${components[@]}" # return all of be created k8s component
}

function getK8sYamlFiles (){
  local prod=2;
  # 依照順序建立 k8s component, 例如: deployment 可能會需要 sercret ...etc等
  local k8s_components=(secret configMap ingress service deployment);
  local envs=(dev development);
  local files=();

  case $ENVIROMENT in
    $prod | "prod" | "production")
      envs=(prod production)
      ;;
  esac

  for conponent in ${k8s_components[@]}
    do
      local component_files=(
        "$(find . -type f -name "*$conponent*-${envs[0]}.yaml")" # dev | prod
        "$(find . -type f -name "*$conponent*-${envs[1]}.yaml")" # development | production
      );

      if [ ${#component_files[@]} ]; then
        for component_file in ${component_files[@]}
          do
            if [ -f $component_file ]; then
              files+=($component_file);
            fi
          done
      fi
    done

  if [ ${#files[@]} ]; then
    echo ${files[@]}
  fi
}

function start() {
  local FILES=$(getK8sYamlFiles);

  if ! [[ $FILES ]]; then
    echo -e "${COLOR_RED}Sorry, coundn't found file in current directory to create kubernetes component"
    exit 1
  fi

  for file in ${FILES[@]}
    do
      if [ -f "$file" ]; then
        kubectl apply -f $file | cut -d" " -f1 >> $COMPONENTS_RECORD
      else
        echo "$COLOR_RED $file is not exist";
      fi
    done

  local is_created=true;
  get_components_record $is_created;
}

function end() {
  if [ -f $COMPONENTS_RECORD ]; then
    local IS_SUCCESS=0;
    local components=$(get_components_record);

    for component in ${components[@]}
      do
        echo -e "\n$component is deleting";

        kubectl delete $component;

        # $? 代表上一次指令是否執行成功
        if [ $? == $IS_SUCCESS ]; then
          # 目的: 如果 k8s component 被 deleted 後，同步清除 components_record
          # 優化: 每次 delete 後都是用重寫覆蓋的方式, 數量若增大, 這麼做可能不是好辦法
          echo "$(grep -v "$component" $COMPONENTS_RECORD)" > $COMPONENTS_RECORD
        else
          echo -e "${COLOR_RED}Sorry, $component deleted failure\n"
        fi
      done

    # 清空 empty line
    sed -i "" "/^$/d" $COMPONENTS_RECORD;

    if ! [ -s $COMPONENTS_RECORD ]; then
      rm $COMPONENTS_RECORD;
    fi
  fi
}

# 可以建立 func main 來跑腳本, 這邊就沒這麼做了
# main script, COMPONENTS_RECORD 代表 k8s components 是否有被建立
if [ -f $COMPONENTS_RECORD ]; then
  echo -ne "start to delete k8s components\n";

  end;
else
  echo -ne "start to create k8s components\n";

  start;
fi

