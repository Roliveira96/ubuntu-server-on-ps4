# 🎮🐧 Ubuntu Server no PS4

> *"Comprei um videogame. Agora ele roda Docker."* — eu, explicando para a família por que a TV mostra texto verde.

Este repositório registra como transformar um PS4 desbloqueado num **servidor Ubuntu 26.04** sem perder os jogos. O Linux mora num arquivo-imagem no HD interno, nada é reparticionado e o console continua abrindo o sistema dos jogos no boot normal, porque ninguém aqui é louco de apagar os saves.

**Aqui não tem binário.** O repositório traz os links das fontes originais, os scripts e o passo a passo. Um comando baixa tudo, confere os hashes, gera o Ubuntu e monta os arquivos já na estrutura de pastas do PS4:

```sh
git clone <este-repo> ps4-linux && cd ps4-linux
./build.sh                         # gera tudo em out/
PS4_IP=192.168.3.105 ./build.sh    # gera e já envia por FTP, conferindo os hashes
```

Depois disso, falta só a [instalação na TV](#4-instalar-teclado--tv-uma-vez-é-sério-só-uma) e a [pós-instalação](#5-pós-instalação-do-bootou-ao-servidor-de-verdade) (Wi-Fi, IP fixo, GPU, Docker).

> Quer ver o que esse console faz depois de virar servidor? Ele hospeda estagiários no projeto irmão [**PlayStagiário 4**](https://github.com/Roliveira96/host-statation-4-pro).

---

## 📋 Requisitos (leia antes de culpar o script)

### O console

| Requisito | Detalhe |
|---|---|
| **Modelo** | PS4 "fat": **CUH-10xx, CUH-11xx ou CUH-12xx** (southbridge Aeolia/Belize). Slim (CUH-2xxx) e Pro (CUH-7xxx) usam Baikal e precisam de outro kernel e outro initramfs; este repositório **não** atende esses modelos. |
| **Firmware** | Algum que tenha jailbreak e seja suportado pelo [loader v25.1](https://github.com/ps4-linux/ps4-linux-loader#supported-firmwares) (5.05 a 13.52). Este foi testado no **13.02**. Se o seu console já atualizou para um firmware sem jailbreak, sinto muito: ele é só um videogame agora. |
| **Jailbreak** | [GoldHEN](https://github.com/GoldHEN/GoldHEN) ativo, com o servidor **FTP** (porta 2121) e o **BinLoader** (porta 9090). O jailbreak **não sobrevive a um reboot**: a cada desligamento, refaça o exploit. Sim, toda vez. |
| **Espaço no HD interno** | Uns 20 GB livres no mínimo. A imagem do Linux é um arquivo cujo tamanho você escolhe na instalação. Aqui foram 400 GB, porque sim. |
| **Rede** | Wi-Fi (Marvell, aparece como `mlan0`) ou cabo. O PS4 e o PC precisam estar na mesma rede. |

### O hardware em volta

- **Teclado USB:** usado uma única vez, no instalador. Depois disso, tudo é por SSH.
- **TV ou monitor HDMI:** pelo mesmo motivo. Ela volta a ser sua depois.
- **Paciência:** o rootfs é descompactado pela CPU Jaguar, que tem a velocidade de um poeta escrevendo à mão.

### O PC que monta tudo

| Requisito | Detalhe |
|---|---|
| **Sistema** | Linux amd64, preferencialmente Ubuntu ou Debian (o `debootstrap` está lá). |
| **Pacotes** | `sudo apt install curl unzip cpio debootstrap xz-utils` |
| **Permissão** | `sudo`: o rootfs é gerado com debootstrap e chroot. O `build.sh` pede a senha só nessa etapa. |
| **Disco** | ~3 GB livres em `/var/tmp` (área de trabalho do debootstrap) mais ~200 MB no repositório. |
| **Internet** | Para baixar ~35 MB de arquivos de boot e os pacotes do Ubuntu. |
| **Chave SSH** | `~/.ssh/id_ed25519.pub` (ou outra, via `SSH_KEY`). Ela é autorizada no Ubuntu para você entrar sem senha. |

---

## 🔗 De onde vem cada peça

| Peça | Versão | Fonte |
|---|---|---|
| Kernel (`bzImage`) | 7.1.7-Strawberry-Server-FullLTO (Aeolia/Belize) | [rmuxnet/linux](https://gitlab.com/rmuxnet/linux) ([zip direto](https://gitlab.com/api/v4/projects/rmuxnet%2Flinux/packages/generic/Release-7%2E1%2E7-Aeolia-Belize/Release-7%2E1%2E7-Aeolia-Belize/7%2E1%2E7-Strawberry-Server-FullLTO%2Ezip)) |
| Initramfs | build-5096995 | [GayCorp/initramfs-ps4](https://github.com/GayCorp/initramfs-ps4) (commit [`5096995`](https://github.com/GayCorp/initramfs-ps4/tree/50969950ecd25f0d6bc24f20af95c3bf3a93ff24)) |
| Payload (`linux-128mb.bin`) | v25.1 | [ps4-linux/ps4-linux-loader](https://github.com/ps4-linux/ps4-linux-loader/releases/tag/v25.1) |
| Rootfs Ubuntu | 26.04 "resolute" | Gerado na hora por [`build-ubuntu-server.sh`](build-ubuntu-server.sh), via debootstrap no [archive.ubuntu.com](http://archive.ubuntu.com/ubuntu/dists/resolute/) |
| Docker Engine | 29 | [Repositório APT oficial](https://docs.docker.com/engine/install/ubuntu/) |
| Firefox (opcional) | — | [Repositório APT da Mozilla](https://support.mozilla.org/kb/install-firefox-linux), porque snap num Jaguar é crueldade |

Antes de cair no Ubuntu, também passamos pelo [CachyOS Strawberry Server](https://github.com/sony-jaguar-devs/distros/releases/tag/CachyOS_Strawberry_Server). Funciona, mas a gente queria um `apt`.

### 📚 Leituras que salvaram o dia

- [DionKill — PS4 Linux tutorial](https://dionkill.github.io/ps4-linux-tutorial/), em especial a [instalação interna](https://dionkill.github.io/ps4-linux-tutorial/internal-installation.html)
- [PS4Linux-Documentation (Hakkuraifu)](https://github.com/Hakkuraifu/PS4Linux-Documentation)
- [ps4linux.com — downloads](https://ps4linux.com/downloads/) e [documentação AIO](https://ps4linux.com/ps4-linux-documentation-aio/)
- [pwn.guide — PS4 Linux](https://pwn.guide/free/hardware/ps4-linux)
- [psxhax — guia do psxitarch (hippie68)](https://www.psxhax.com/threads/guide-to-install-psxitarch-linux-on-ps4-enable-wi-fi-and-more-by-hippie68.10148/)
- [better-initramfs](https://bitbucket.org/piotrkarbowski/better-initramfs), avô do initramfs do PS4
- [ps4boot/ps4-linux-payloads](https://github.com/ps4boot/ps4-linux-payloads), payloads alternativos

---

## 🛠️ Passo a passo

### 1. Rodar o `build.sh`

| Etapa | O que acontece |
|---|---|
| 1. Download | Baixa o kernel, o initramfs e os payloads. O que já estiver baixado e íntegro é reaproveitado. |
| 2. Verificação | Confere tudo contra o [`SHA256SUMS`](SHA256SUMS). Hash errado interrompe o build. |
| 3. Rootfs | Roda o `build-ubuntu-server.sh` com sudo (detalhes [abaixo](#2-o-que-vem-no-ubuntu)). Leva alguns minutos; aproveite para pegar um café. |
| 4. Montagem | Copia os arquivos para `out/` com os mesmos caminhos do PS4 e gera `out/SHA256SUMS`. |
| 5. Envio (opcional) | Com `PS4_IP`, envia `out/` pelo FTP do GoldHEN e confere o hash de cada arquivo já dentro do PS4. |

O `out/` fica assim:

```
out/
├── data/linux/boot/bzImage              kernel (o payload procura aqui)
├── data/linux/boot/initramfs.cpio.gz    initramfs
├── data/GoldHEN/payloads/linux-128mb.bin
└── user/system/boot/distro.tar.xz       Ubuntu (lido pelo instalador)
```

#### Variáveis

| Variável | Padrão | Uso |
|---|---|---|
| `PS4_IP` | (vazio) | IP do PS4. Se definida, faz o envio por FTP. |
| `FTP_PORT` | `2121` | Porta do FTP do GoldHEN. |
| `PAYLOAD` | `linux-128mb.bin` | VRAM reservada para a GPU. 128 MB basta para servidor; para desktop, use `linux-1024mb.bin` ou mais. |
| `SKIP_ROOTFS` | `0` | Com `1`, reaproveita um `ubuntu-26.04-server.tar.xz` já gerado. |
| `USER_NAME` | seu usuário | Usuário criado no Ubuntu. |
| `USER_PASS` | `ps4ubuntu` | Senha provisória, que precisa ser trocada no primeiro login. Não se apegue a ela. |
| `HOSTNAME_NEW` | `ps4-server` | Hostname. |
| `SSH_KEY` | `~/.ssh/id_ed25519.pub` | Chave pública autorizada no SSH. |
| `SUITE` / `MIRROR` | `resolute` / archive.ubuntu.com | Versão e mirror do Ubuntu. |

#### 🧟 O caso do initramfs que sumiu

O upstream apaga builds antigos e hoje só mantém um `latest` contínuo, que muda a cada commit. Se o build fixado (`build-5096995`) não existir mais, o `build.sh` faz uma pequena necromancia:

1. baixa o código-fonte do mesmo commit `5096995`;
2. pega o firmware de GPU e Wi-Fi do build `latest`, já que o autor guarda o firmware num repositório privado;
3. descarta o firmware do PS4 Pro (`gladius_*`), que entrou no upstream depois do nosso commit;
4. empacota do mesmo jeito que o `bake.sh` original;
5. compara o **hash do conteúdo** com o do initramfs que foi testado no console. Se for diferente, o build para.

### 2. O que vem no Ubuntu

O `build-ubuntu-server.sh` gera um Ubuntu Server enxuto:

- Debootstrap do Ubuntu 26.04 (main e universe), **sem kernel nem GRUB**. O apt fica proibido de instalá-los, porque o kernel do PS4 é o `bzImage` e qualquer outro só atrapalharia.
- Locale pt_BR, fuso de São Paulo e teclado US internacional.
- Netplan com DHCP no cabo e `systemd-networkd-wait-online` mascarado, para o boot não ficar dois minutos esperando um cabo que não existe.
- Usuário no grupo sudo, com senha provisória, root bloqueado e chave SSH autorizada.
- Firmware de GPU e Wi-Fi copiado do initramfs.
- Chaves de host SSH geradas no primeiro boot, únicas por máquina.

### 3. Enviar para o PS4

Se `PS4_IP` foi usado, este passo já está feito. Para enviar à mão:

```sh
cd out && find . -type f ! -name SHA256SUMS -printf '%P\n' | while read -r f; do
  curl --ftp-create-dirs -T "$f" "ftp://<IP-DO-PS4>:2121/$f"; done
```

### 4. Instalar (teclado + TV, uma vez, é sério, só uma)

1. No GoldHEN, carregue o payload `linux-128mb.bin`. A tela vai ficar preta por alguns segundos, e isso é normal.
2. O initramfs abre um `rescueshell` na TV. Rode `install-linux-int.sh`, informe o tamanho da imagem em GB e escolha **ext4**. A imagem é criada em `/user/home/linux.img`, sem tocar nos jogos.
3. Rode `resume-boot` para entrar no Ubuntu.
4. Faça login e troque a senha provisória.
5. Desconecte o teclado. A partir daqui é SSH: `ssh <usuario>@<IP-DO-PS4>`.

### 5. Pós-instalação: do "bootou" ao "servidor de verdade"

O Ubuntu sobe, mas sai da fábrica só com cabo, IP aleatório e uma GPU que ninguém apresentou ao usuário. Estes são os ajustes que foram feitos neste PS4, na ordem em que fazem sentido. Os scripts ficam na raiz do repositório: copie para o PS4 (`scp ps4-*.sh <usuario>@<IP-DO-PS4>:`) e rode lá. Até o Wi-Fi estar de pé, o SSH é pelo cabo.

#### 5.1. Wi-Fi

O Wi-Fi Marvell aparece como `mlan0` e o firmware já vem no rootfs.

```sh
sudo nano /etc/netplan/02-wifi.yaml    # cole examples/02-wifi.yaml.example com seu SSID e senha
sudo chmod 600 /etc/netplan/02-wifi.yaml
sudo netplan apply
ip -4 -br addr show mlan0
```

Se estiver no SSH pelo cabo, pode aplicar sem medo; se estiver no SSH pelo próprio Wi-Fi, prepare-se para reconectar.

#### 5.2. IP fixo e hostname

Ajuste `NEW_HOSTNAME`, `IFACE`, `ADDRESS` e `GATEWAY` no topo do script e rode:

```sh
sudo bash ps4-setup-static-ip.sh
```

Ele cria `/etc/netplan/03-static-ip.yaml`, que é mesclado por cima do `02-wifi.yaml` (SSID e senha continuam lá), e aplica em segundo plano. Se o IP mudou, a sessão SSH cai: reconecte no IP novo. O IP fixo é a forma de o `ssh` e o FTP do `build.sh` acharem o console sempre no mesmo lugar.

#### 5.3. GPU: OpenGL e Vulkan

O driver `amdgpu` e o firmware `liverpool_*` já funcionam com o kernel e o rootfs deste repositório. Falta só o lado do usuário:

```sh
sudo bash ps4-setup-gpu.sh
exit   # saia e entre de novo no SSH para os grupos valerem
```

O script instala `mesa-vulkan-drivers`, `mesa-utils` e `vulkan-tools`, põe o usuário nos grupos `video` e `render` e confere tudo. O resultado esperado:

| API | Driver | Como aparece |
|---|---|---|
| OpenGL 4.5 / GLES 3.2 | radeonsi (ACO) | `AMD DG1301SML87HY (radeonsi, kaveri, ...)` |
| Vulkan | RADV | `GPU 0: 1002:9924 ... (RADV KAVERI)` (o `llvmpipe` é a GPU 1, na CPU) |

Sim, ele se apresenta como **kaveri**. O PS4 é parente de APU de notebook e não tem vergonha disso.

#### 5.4. Docker

```sh
sudo bash ps4-install-docker.sh
```

Instala o Docker Engine e o plugin Compose pelo repositório oficial (não o `docker.io` do Ubuntu), liga o serviço e põe o usuário no grupo `docker`. Saia e entre de novo. Confira que o cgroup é o certo, porque limites de memória por container dependem disso:

```sh
docker info --format '{{.CgroupDriver}} {{.CgroupVersion}}'   # systemd 2
```

#### 5.5. Desktop XFCE sob demanda (opcional)

```sh
sudo bash ps4-install-xfce.sh
```

Instala um XFCE mínimo com Xorg + amdgpu, LightDM e Firefox `.deb` (repositório da Mozilla, sem snap). O ponto principal: **o boot continua em modo texto**. O LightDM fica desabilitado e o alvo padrão é `multi-user.target`, porque na maior parte do tempo o PS4 está sem TV, só no SSH. Quando quiser a interface:

```sh
desktop       # liga o LightDM na TV
desktop-off   # desliga e devolve a RAM
```

Não rode `systemctl enable lightdm` nem `set-default graphical.target`: o PS4 passaria a gastar memória com uma tela que ninguém está olhando. Para desktop, também vale usar um payload com mais VRAM (`PAYLOAD=linux-1024mb.bin`).

#### 5.6. HD externo USB (opcional)

Um HD USB em **exFAT** funciona dos dois lados: o PS4 em modo jogo e o Linux leem o mesmo disco (o kernel já tem exFAT embutido). Aqui ele é montado em `/mnt/compartilhado`:

```sh
sudo apt install -y exfatprogs
sudo blkid | grep exfat                 # pegue o UUID
sudo mkdir -p /mnt/compartilhado
echo 'UUID=XXXX-XXXX /mnt/compartilhado exfat uid=1000,gid=1000,umask=022,nofail,x-systemd.device-timeout=10s 0 0' \
  | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount /mnt/compartilhado
ln -s /mnt/compartilhado ~/compartilhado
```

O `nofail` e o `x-systemd.device-timeout=10s` são obrigatórios: sem eles, um boot com o HD desconectado fica parado esperando o disco e cai no modo de emergência, e você vai precisar de teclado e TV de novo.

#### 5.7. Trazer volumes Docker de outra máquina (opcional)

`migrate-docker-volumes.sh` roda **no computador antigo**: copia volumes nomeados com os mesmos labels, faz dumps dos bancos e compara checksums dos dois lados. Ajuste `REMOTE` e a lista `VOLUMES` antes.

#### 5.8. Conferência final

```sh
cat /proc/cmdline | grep -o 'amdgpu.dpm=0'               # precisa estar lá
findmnt -no SOURCE,FSTYPE /                              # /dev/loop0 ext4
ip -4 -br addr show mlan0                                # IP fixo
systemctl get-default                                    # multi-user.target
systemctl is-enabled fstrim.timer                        # enabled
id -nG | tr ' ' '\n' | grep -E '^(video|render|docker)$'  # três grupos
eglinfo -B | grep -m1 renderer                           # radeonsi
docker run --rm hello-world | grep -m1 Hello
```

Passou em tudo? O PS4 agora é um servidor. Para dar um emprego a ele, veja [🎮 E agora?](#-e-agora-o-que-roda-nesse-ps4).

---

## 🆘 Dicas e pegadinhas

- **Boot normal = jogos. Payload = Linux.** Eles convivem em paz.
- **O BinLoader do GoldHEN (porta 9090) aceita uma única conexão.** Se você testar a porta antes de mandar o payload, gastou a vez dele.
- **Não instale kernel pelo apt.** O kernel é sempre o `bzImage` em `/data/linux/boot`. Para atualizar, troque esse arquivo.
- **Tela preta depois do payload?** Confira se o modelo é CUH-10xx/11xx/12xx e se o `bzImage` chegou inteiro (veja o `out/SHA256SUMS`).
- **Nunca ligue o DPM da GPU.** O kernel sobe com `amdgpu.dpm=0` (e `radeon.dpm=0`) de propósito: com o gerenciamento de energia ligado, o PS4 trava. A GPU fica no clock fixo, e tudo bem.
- **`vulkaninfo --summary` dá `ERROR_OUT_OF_HOST_MEMORY` sem monitor.** É a consulta de telas falhando no modo headless, não falta de memória. Use `MESA_VK_DEVICE_SELECT=list vulkaninfo`.
- **Swap em disco, não.** O sistema inteiro já roda dentro de um arquivo no HD lento do PS4 (`/dev/loop0`); swap ali é lenta e pode travar justamente quando falta memória. Se precisar de swap, use zram (comprimida na RAM, o kernel já tem): há um [script pronto](https://github.com/Roliveira96/host-statation-4-pro/blob/main/scripts/configurar-sistema.sh) no projeto irmão.
- **O kernel não tem suporte a quota** (`CONFIG_QUOTA` desligado). Para limitar disco por usuário, use uma imagem ext4 em loop para cada um, montada pelo `/etc/fstab`.
- **O ventilador vai trabalhar.** O PS4 fat tem um jato turbofan embutido; trate a pasta térmica com carinho.

## 🎮 E agora? O que roda nesse PS4

Este repositório termina com um Ubuntu Server pronto, sem nenhum serviço de verdade. O que esse PS4 faz da vida está no projeto irmão:

**[🎮 PlayStagiário 4 — host-statation-4-pro](https://github.com/Roliveira96/host-statation-4-pro)**: hospedagem estilo Hostinger para estagiários (site por subdomínio, PHP, MariaDB, phpMyAdmin, painel de arquivos e SSH), tudo em Docker e exposto por um túnel da Cloudflare, sem IP fixo nem porta aberta no roteador.

A ordem é: este repositório (Linux no console) ➜ pós-instalação acima ➜ [instalação do PlayStagiário 4](https://github.com/Roliveira96/host-statation-4-pro/blob/main/docs/instalacao.md).

## ⚠️ Aviso

Projeto de hobby, sem relação com a Sony. Jailbreak e Linux em console por sua conta e risco. Se o PS4 virar peso de porta, a gente sente muito, mas não reembolsa.
