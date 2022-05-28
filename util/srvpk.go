/*srvpk.go*/
package main
import (
	"net/http"
	"log"
	"os"
	"github.com/bitfield/script"
	"github.com/gorilla/mux"
)


func ServePK(w http.ResponseWriter, r *http.Request) {
	pk, err := script.Exec(`skywire-cli visor pk`).Bytes()
	if err != nil {
	log.Printf("error occured")
	os.Exit(1)
}
	w.Write([]byte(pk))
}

func main() {
    r := mux.NewRouter()
    // Routes consist of a path and a handler function.
    r.HandleFunc("/", ServePK)

    // Bind to a port and pass our router in
    log.Fatal(http.ListenAndServe(":7998", r))
}
