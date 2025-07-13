# Prompt per il Refactoring di un Controller Laravel

Utilizza questo template per richiedere il refactoring di un controller Laravel "fat". Inserisci il codice sorgente nelle sezioni apposite e l'AI seguirà le linee guida per produrre un'architettura pulita, testabile e manutenibile.

## 📝 Inserisci qui il Controller da rifattorizzare

```php
<?php

// Incolla qui il codice completo del Controller da rifattorizzare.
// Esempio: App\Http\Controllers\UserController.php

?>
```

## 📦 Inserisci qui il Model Eloquent principale

```php
<?php

// Incolla qui il codice del Model Eloquent principale associato al controller.
// Esempio: App\Models\User.php

?>
```

## 🔗 Inserisci qui eventuali Model o Service correlati (Opzionale)

Se il controller o il model principale interagiscono con altri modelli o service in modo significativo (es. per relazioni complesse o logiche di business dipendenti), incollali qui per fornire un contesto completo.

```php
<?php

// Incolla qui eventuali Model o Service correlati che sono importanti
// per capire la logica di business o le relazioni.

?>
```

---

## Linee Guida per il Refactoring

1. **FormRequest**:
    - Estrai tutta la validazione in classi dedicate: `App\Http\Requests\<Controller>\<ActionName>Request`.
    - Per le richieste di elenchi (`index`), estendi `PaginatedRequest` se hai bisogno di aggiungere filtri di ricerca (es. `term`, `status`).
    - Nei metodi del controller, i dati di input devono provenire **solo** dal FormRequest appropriato.

2. **Service Statico**:
    - Crea una classe `App\Services\<Controller>Service` con metodi statici.
    - Ogni metodo deve incapsulare una singola unità di lavoro (es. `list`, `store`, `update`), gestire le transazioni (`DB::transaction`) e contenere tutta la logica di business.
    - I metodi del Service devono accettare parametri primitivi o DTO, **mai** l'oggetto `Request`.
    - **Service Esterni**: Se la logica di business interagisce con altri Controller (es. `new AltroController()`), sostituisci queste chiamate con chiamate a un `AltroService`. Se tale service non esiste ancora, lascia un commento `// TODO: Implementare o verificare AltroService::metodo()` per segnalare la dipendenza.
    - Il service deve restituire modelli Eloquent, collezioni, `LengthAwarePaginator` (da `->paginate()`), DTO o valori primitivi.

3. **Controller "Slim"**:
    - I metodi del controller devono solo iniettare i FormRequest e i parametri di rotta tipizzati (es. `int $id`).
    - Ogni metodo deve contenere una singola chiamata al Service e non avere logica aggiuntiva.
    - Utilizza **solo** le classi `ResultResponse` e `ErrorResponse` per le risposte JSON, passando i dati attraverso le API Resource.

4. **Paginazione**:
    - Sostituisci qualsiasi implementazione di paginazione manuale con il metodo nativo di Eloquent `->paginate($request->pageSize())`, da usare all'interno del Service.

5. **Risorse e Data Objects**:
    - Per ogni entità restituita, crea una `App\Http\Resources\<Model>Resource` e, se pertinente, un `App\Data\<Model>\<Model>Data` (usando Spatie/Laravel-Data).
    - Usa le Resource per formattare l'output JSON in modo coerente.

6. **Elenco Classi Coinvolte**:
    - Alla fine dell'output, fornisci un elenco completo di tutte le classi nuove o modificate durante il refactoring.

7. **Spiegazione**:
    - Concludi con una breve spiegazione delle decisioni architetturali prese e dei benefici ottenuti.

---

## 🛠️ Classi di Supporto (Riferimento)

Le seguenti classi definiscono la struttura standard per le richieste paginate e le risposte JSON.

### `PaginatedRequest` (Base per la paginazione)

```php
<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class PaginatedRequest extends FormRequest
{
     public function authorize(): bool { return true; }

     public function rules(): array
     {
          return [
                'page'      => 'sometimes|integer|min:1',
                'page_size' => 'sometimes|integer|min:1',
          ];
     }

     public function page(): int { return (int) $this->input('page', 1); }

     public function pageSize(): int { return (int) $this->input('page_size', 15); }
}
```

### `ResultResponse` (Risposta JSON per successo)

```php
<?php

namespace App\Http\Responses;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class ResultResponse implements Responsable
{
     public function __construct(
          public readonly string $message = 'OK',
          public readonly mixed $data = null,
          public readonly int $status = JsonResponse::HTTP_OK,
     ) {}

     public function toResponse($request): Response
     {
          $payload = ['message' => $this->message];
          if (!is_null($this->data)) {
                $payload['data'] = $this->data;
          }
          return new JsonResponse(data: $payload, status: $this->status);
     }
}
```

### `ErrorResponse` (Risposta JSON per errore)

```php
<?php

namespace App\Http\Responses;

use Illuminate\Contracts\Support\Responsable;
use Illuminate\Http\JsonResponse;
use Symfony\Component\HttpFoundation\Response;

class ErrorResponse implements Responsable
{
     public function __construct(
          public readonly string $message = 'Errore di sistema',
          public readonly int $status = JsonResponse::HTTP_INTERNAL_SERVER_ERROR,
     ) {}

     public function toResponse($request): Response
     {
          return new JsonResponse(
                data: ['message' => $this->message],
                status: $this->status,
          );
     }
}
```
