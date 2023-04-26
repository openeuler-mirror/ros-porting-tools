# ros-tools

#### 介绍
本仓库用于自动引入ros到openEuler上。

#### 使用说明
1. 执行get-repo-list.sh
2. 执行vcs import src < ros.repos #下载ros源码到src目录下
3. 执行get-pkg-src.sh ros源码下载目录
3. 执行get-pkg-deps.sh ros源码下载目录
4. 执行gen-pkg-spec.sh ros源码下载目录 #在output/ros-repo目录下生成ros仓库和对应的tar包以及spec
5. 上传tar包和spec到对应的ros仓库即可。

#### 脚本用途介绍
|脚本名称|输入|输出|作用|
|---|---|---|---|
|get-ros-projects.sh|http://repo.ros2.org/status_page<br>/ros_humble_default.html|humble/ros-projects.list|支持自动分析http://repo.ros2.org/status_page/ros_humble_default.html页面获取软件包名、仓库地址、软件包状态、版本号|
|get-repo-list.sh|humble/ros-projects.list<br>humble/ros-version-fix|output/ros-pkg.list<br>output/ros-projects-name.list<br>output/ros.repos<br>output/ros.url|output/ros-pkg.list #软件包名、对应的仓库地址、版本号<br>output/ros-projects-name.list #软件仓库的名称<br>output/ros.repos #用于下载上游软件包<br>output/ros.url #所有上游仓库地址|
|get-src-from-github.sh<br>get-src-from-ubuntu.sh|output/ros.repos|output/src|src目录下会自动下载所有上游仓库|
|get-pkg-src.sh|output/ros-pkg.list|output/ros-pkg-src.list|生成 软件包名、对应上游仓库内的路径、版本号|
|get-pkg-deps.sh|output/ros-pkg-src.list<br>output/ros-pkg.list|output/pkg<br>BuildRequires         <br>ExtDeps               <br>PackageXml            <br>PackageXml-description<br>Requires              <br>test-BuildRequires    |生成软件包的依赖<br>BuildRequires         #构建依赖<br>ExtDeps               #外部依赖<br>PackageXml            #提取package.xml中的关键元素<br>PackageXml-description #软件包描述信息<br>Requires              #运行依赖<br>test-BuildRequires #自验证依赖|
|gen-pkg-spec.sh|output/ros-pkg-src.list<br>output/ros-pkg.list|output/repo|自动生成src-openeuler组织下的仓库、软件tar.gz包、spec、_multibuild文件|
|get-deps-src.sh|output/deps|output/ros-deps.list<br>output/ros-deps-src.list|在Ubuntu系统上查找对应的软件包的源码包<br>output/ros-deps.list #外部依赖列表<br>output/ros-deps-src.list #外部依赖、源码包|

#### 参与贡献

1.  Fork 本仓库
2.  新建 Feat_xxx 分支
3.  提交代码
4.  新建 Pull Request
