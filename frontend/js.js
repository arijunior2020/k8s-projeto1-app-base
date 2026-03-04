const DEFAULT_API_URL = "http://127.0.0.1:30080";

function normalizeApiUrl(rawUrl) {
    if (!rawUrl) {
        return rawUrl;
    }

    if (rawUrl.startsWith("http://") || rawUrl.startsWith("https://")) {
        return rawUrl;
    }

    return "http://" + rawUrl;
}

function resolveApiUrl() {
    const queryApiUrl = new URLSearchParams(window.location.search).get("api");
    if (queryApiUrl) {
        const normalizedApiUrl = normalizeApiUrl(queryApiUrl);
        localStorage.setItem("backend_api_url", normalizedApiUrl);
        return normalizedApiUrl;
    }

    return normalizeApiUrl(localStorage.getItem("backend_api_url")) || DEFAULT_API_URL;
}

$("#button-blue").on("click", function() {
    var txt_nome = $("#name").val();
    var txt_email = $("#email").val();
    var txt_comentario = $("#comment").val();
    var apiUrl = resolveApiUrl();

    $.ajax({
        url: apiUrl,
        type: "post",
        data: {nome: txt_nome, comentario: txt_comentario, email: txt_email},
        beforeSend: function() {
            console.log("Tentando enviar os dados para:", apiUrl);
        }
    }).done(function(response) {
        console.log("Resposta backend:", response);
        alert("Dados salvos");
    }).fail(function(xhr) {
        console.error("Falha ao enviar dados:", xhr.status, xhr.responseText);
        alert("Erro ao enviar dados. Verifique a URL da API.");
    });
});
