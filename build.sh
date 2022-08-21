#!/bin/bash
WORKINGDIR=$(pwd)
VERSION="Skybian_Maintenance_Framework_1.1.0"
DIALOG=dialog
DIALOG1="$DIALOG --backtitle $VERSION --clear --cancel-label Exit --no-collapse"
#set -ex
HIGHLIGHT=0

# Define the dialog exit status codes
: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

# Create a temporary file and make sure it goes away when we're dome
tmp_file=$(tempfile 2>/dev/null) || tmp_file=/tmp/test$$
trap "rm -f $tmp_file" 0 1 2 5 15

build_image() {
	$DIALOG1 \
	--title "Main Menu" \
	--menu "Please select: " 0 0 10 \
	"1" "Build the Skybian Orange Pi Prime image" \
	"2" "Build the Skybian Orange Pi Prime image with autopeering" \
	"3" "Build the Skybian Orange Pi 3 image" \
	"4" "Build the Skyraspbian Raspberry Pi 3 image" \
	"5" "Build the Skyraspbian Raspberry Pi 4 image" \
	"6" "main menu" \
	2> $tmp_file
	# HIGHLIGHT=$(cat ${ANSWER})
	case $(cat $tmp_file) in
	"1")
	clear
	SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"2")
	clear
	ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"3")
	clear
	SKYBIAN=skybian.opi3.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"4")
	clear
	SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"5")
	clear
	SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"6")
	main_menu
	;;
	*)
	clear
	exit 1
	;;
	esac

}
build_test_image() {
	$DIALOG1 \
	--title "Main Menu" \
	--menu "Please select: " 0 0 10 \
	"1" "Build the Skybian Orange Pi Prime test image" \
	"2" "Build the Skybian Orange Pi Prime test image with autopeering" \
	"3" "Build the Skybian Orange Pi 3 test image" \
	"4" "Build the Skyraspbian Raspberry Pi 3 test image" \
	"5" "Build the Skyraspbian Raspberry Pi 4 test image" \
	"6" "main menu" \
	2> $tmp_file
	# HIGHLIGHT=$(cat ${ANSWER})
	case $(cat $tmp_file) in
	"1")
	clear
	TESTDEPLOYMENT=1 SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"2")
	clear
	TESTDEPLOYMENT=1 ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"3")
	clear
	TESTDEPLOYMENT=1 SKYBIAN=skybian.opi3.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"4")
	clear
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"5")
	clear
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh zip
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"6")
	main_menu
	;;
	*)
	clear
	exit 1
	;;
	esac

}

main_menu() {
	$DIALOG1 \
	--title "Main Menu" \
	--menu "Please select: " 0 0 10 \
	"1" "Create the Skybian Package" \
	"2" "Create the Skybian package with test repo config" \
	"3" "Remove built packages" \
	"4" "Update IMGBUILD Checksums" \
	"5" "Update IMGBUILD Checksums for test package" \
	"6" "Build individual image & zip archive" \
	"7" "Build individual test image & zip archive" \
	"8" "Build all the Skybian images & zip archives" \
	"9" "Build all the Skybian test images & zip archives" 2> $tmp_file
	# HIGHLIGHT=$(cat ${ANSWER})
	case $(cat $tmp_file) in
	"1")
	clear
	source PKGBUILD
	./skybian.sh wait
	_err=$?
	if $_err != "0" ; then
	$DIALOG1 \
	--title "Error creating the skybian package:" --msgbox "
	exit status $_err" 10 0
	else
	$DIALOG1 \
	--title "skybian package created:" --msgbox "
	$(ls ${pkgname}-${pkgver}*.deb)" 10 0
	fi
	;;
	"2")
	clear
	source PKGBUILD
	TESTDEPLOYMENT=1 ./skybian.sh wait
	_err=$?
	if $_err != "0" ; then
	$DIALOG1 \
	--title "Error creating the skybian package:" --msgbox "
	exit status $_err" 10 0
	else
	$DIALOG1 \
	--title "skybian package created:" --msgbox "
	$(ls ${pkgname}-${pkgver}*.deb)" 10 0
	fi
	;;
	"3")
	clear
	rm -rf *.deb
	$DIALOG1 \
	--title "Removed" --msgbox "Removed existing .deb packages" 5 40
	;;
	"4")
	clear
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skybian.prime.IMGBUILD ./image.sh 0
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skybian.opi3.IMGBUILD ./image.sh 0
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh 0
	SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh 0
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"5")
	clear
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skybian.prime.IMGBUILD ./image.sh 0
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skybian.opi3.IMGBUILD ./image.sh 0
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh 0
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh 0
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"6")
	clear
	build_image
	;;
	"7")
	build_test_image
	;;
	"8")
	clear
	set -e
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skybian.opi3.IMGBUILD ./image.sh zip
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh zip
	SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh zip
	set +e
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	"9")
	clear
	set -e
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	TESTDEPLOYMENT=1 ENABLEAUTOPEER="-autopeer" SKYBIAN=skybian.prime.IMGBUILD ./image.sh zip
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skybian.opi3.IMGBUILD ./image.sh zip
	[[ $(echo *.sha) != "*.sha" ]] && rm *.sha
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi3.IMGBUILD ./image.sh zip
	TESTDEPLOYMENT=1 SKYBIAN=skyraspbian.rpi4.IMGBUILD ./image.sh zip
	set +e
	read -s -n 1 -p "Press any key to continue . . ."
	echo ""
	;;
	*)
	clear
	exit 1
	;;
esac
main_menu
}

while true; do
main_menu
done
