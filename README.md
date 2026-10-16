# 🎮🐧 Ubuntu Server no PS4

> *"Comprei um videogame. Agora ele roda Docker."* — eu, explicando para a família por que a TV mostra texto verde.

Este repositório registra como transformar um PS4 desbloqueado num **servidor Ubuntu 26.04** sem perder os jogos. O Linux mora num arquivo-imagem no HD interno, nada é reparticionado e o console continua abrindo o sistema dos jogos no boot normal, porque ninguém aqui é louco de apagar os saves.

**Aqui não tem binário.** O repositório traz os links das fontes originais, os scripts e o passo a passo. Um comando baixa tudo, confere os hashes, gera o Ubuntu e monta os arquivos já na estrutura de pastas do PS4:

```sh
git clone <este-repo> ps4-linux && cd ps4-linux
./build.sh                         # gera tudo em out/
PS4_IP=192.168.3.105 ./build.sh    # gera e já envia por FTP, conferindo os hashes
```

Depois disso, falta só a [instalação na TV](#4-instalar-teclado--tv-uma-vez-é-sério-só-uma).

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

### 5. Pós-instalação

| O quê | Como |
|---|---|
| **Wi-Fi** | Copie [`examples/02-wifi.yaml.example`](examples/02-wifi.yaml.example) para `/etc/netplan/02-wifi.yaml`, rode `chmod 600` e `sudo netplan apply`. |
| **IP fixo e hostname** | `sudo bash ps4-setup-static-ip.sh`. Ajuste as variáveis no topo do script antes. |
| **Docker** | `sudo bash ps4-install-docker.sh` |
| **Desktop XFCE sob demanda** | `sudo bash ps4-install-xfce.sh`. O boot continua em texto: `desktop` liga a interface gráfica e `desktop-off` desliga. |
| **Trazer volumes Docker de outra máquina** | `migrate-docker-volumes.sh`. Copia volumes nomeados com os mesmos labels, faz dumps dos bancos e compara checksums. |

---

## 🆘 Dicas e pegadinhas

- **Boot normal = jogos. Payload = Linux.** Eles convivem em paz.
- **O BinLoader do GoldHEN (porta 9090) aceita uma única conexão.** Se você testar a porta antes de mandar o payload, gastou a vez dele.
- **Não instale kernel pelo apt.** O kernel é sempre o `bzImage` em `/data/linux/boot`. Para atualizar, troque esse arquivo.
- **Tela preta depois do payload?** Confira se o modelo é CUH-10xx/11xx/12xx e se o `bzImage` chegou inteiro (veja o `out/SHA256SUMS`).
- **O ventilador vai trabalhar.** O PS4 fat tem um jato turbofan embutido; trate a pasta térmica com carinho.

## ⚠️ Aviso

Projeto de hobby, sem relação com a Sony. Jailbreak e Linux em console por sua conta e risco. Se o PS4 virar peso de porta, a gente sente muito, mas não reembolsa.
